{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.t3os.module.projects.personal.smallweb;
  state = "/var/lib/smallweb";
  repo = "${state}/homepage";
  site = "${repo}/t3";
  env = {
    GOPHER_HOST = cfg.gopherHost;
    GOPHER_PORT = "70";
    GEMINI_HOST = cfg.geminiHost;
    GEMINI_PORT = "1965";
    HOME = state;
  };
  base = {
    User = "smallweb";
    Group = "smallweb";
    StateDirectory = "smallweb";
  };
  server = name: {
    description = "homepage ${name} server";
    wantedBy = [ "multi-user.target" ];
    wants = [ "smallweb-build.service" ];
    after = [ "smallweb-build.service" ];
    environment = env;
    serviceConfig = base // {
      WorkingDirectory = site;
      ExecStart = "${pkgs.nodejs_24}/bin/node ${site}/node_modules/.bin/tsx scripts/${name}.ts";
      Restart = "always";
      RestartSec = 5;
    };
  };
in
{
  config = lib.mkIf cfg.enable {
    users.users.smallweb = {
      isSystemUser = true;
      group = "smallweb";
      home = state;
    };
    users.groups.smallweb = { };

    systemd.services.smallweb-build = {
      description = "build homepage gopher and gemini content";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      environment = env;
      path = [
        pkgs.git
        pkgs.nodejs_24
        pkgs.coreutils
        pkgs.bash
      ];
      script = ''
        if [ ! -d ${repo}/.git ]; then
          git clone https://github.com/Flonk/homepage.git ${repo}
        fi
        cd ${repo}
        git fetch origin main
        target=$(git rev-parse origin/main)
        if [ -f ${state}/built ] && [ "$(cat ${state}/built)" = "$target ${cfg.gopherHost} ${cfg.geminiHost}" ] && [ -f t3/dist/gopher/gophermap ]; then
          exit 0
        fi
        git reset --hard "$target"
        cd t3
        npm ci --no-audit --no-fund
        mkdir -p ${state}/gemini-cert node_modules/.cache
        ln -sfn ${state}/gemini-cert node_modules/.cache/gemini
        npm run build
        echo "$target ${cfg.gopherHost} ${cfg.geminiHost}" > ${state}/built
      '';
      serviceConfig = base // {
        Type = "oneshot";
        TimeoutStartSec = "15min";
      };
    };

    systemd.timers.smallweb-build = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "hourly";
        Persistent = true;
      };
    };

    systemd.services.smallweb-gopher = lib.recursiveUpdate (server "gopher") {
      serviceConfig.AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
    };
    systemd.services.smallweb-gemini = server "gemini";

    networking.firewall.allowedTCPPorts = [
      70
      1965
    ];
  };
}
