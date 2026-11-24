{
  config,
  lib,
  pkgs,
  ...
}:
let
  selenium-stealth = pkgs.python3.pkgs.buildPythonPackage {
    pname = "selenium-stealth";
    version = "1.0.6";
    format = "wheel";
    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/cb/ac/7877df8b819d54a4e317a093a0a9e0a38d21d884a7250aa713f2f0869442/selenium_stealth-1.0.6-py3-none-any.whl";
      hash = "sha256-ti2lRSqkqE8ppN+yGpaWr/IHiKfFcN0LgbwEqUCEi5c=";
    };
    propagatedBuildInputs = with pkgs.python3.pkgs; [
      selenium
      setuptools
    ];
    doCheck = false;
  };

  pythonEnv = pkgs.python3.withPackages (ps: [
    ps.selenium
    selenium-stealth
    ps.xdg-base-dirs
  ]);

  vpn3itConnect = pkgs.stdenv.mkDerivation {
    name = "vpn3it-connect";
    dontUnpack = true;
    installPhase = ''
      install -Dm644 ${./vpn3it-connect.py} $out/lib/vpn3it-connect.py
    '';
  };

  runtimePath = lib.makeBinPath [
    pkgs.chromedriver
    pkgs.chromium
    pkgs.openconnect
    pkgs.chafa
  ];

  hubEnv = {
    VPN3IT_PRIORITY = if cfg.vpn3itPriority then "1" else "0";
    VPN3IT_HOST_NAME = host;
    VPN3IT_HOLDERS_AWK = "${./holders.awk}";
  }
  // lib.optionalAttrs bus.enable {
    VPN3IT_HUB_PORT = if bus.upstream != null then "18830" else "1883";
    VPN3IT_HUB_NAME = if bus.upstream != null then lib.last (lib.splitString "-" bus.upstream) else host;
    VPN3IT_SELF_TOPIC = "${lib.optionalString (bus.upstream != null) "${host}/"}mutex/vpn3it/state";
  };

  vpn3itRun = pkgs.writeShellScriptBin "vpn3it-run" ''
    export IP="${pkgs.iproute2}/bin/ip"
    export AWK="${pkgs.gawk}/bin/awk"
    export BAT="${pkgs.bat}/bin/bat"
    export PYTHON="${pythonEnv}/bin/python3"
    export VPN3IT_CONNECT_PY="${vpn3itConnect}/lib/vpn3it-connect.py"
    export PKILL="${pkgs.procps}/bin/pkill"
    export PGREP="${pkgs.procps}/bin/pgrep"
    export EXTRA_PATH="${runtimePath}"
    export VPN_HOST_FILE="${config.sops.secrets.vpn3ithost.path}"
    export VPN_USER_FILE="${config.sops.secrets.vpn3ituser.path}"
    export VPN_PASS_FILE="${config.sops.secrets.vpn3itpass.path}"
    export MOSQUITTO_SUB="${pkgs.mosquitto}/bin/mosquitto_sub"
    export MOSQUITTO_PUB="${pkgs.mosquitto}/bin/mosquitto_pub"
    ${lib.concatStringsSep "\n    " (lib.mapAttrsToList (k: v: "export ${k}=${lib.escapeShellArg v}") hubEnv)}
    exec ${./vpn3it.sh} "$@"
  '';

  doubletunnelRun = pkgs.writeShellScriptBin "doubletunnel-run" ''
    export AWK="${pkgs.gawk}/bin/awk"
    export OPENVPN="${pkgs.openvpn}/bin/openvpn"
    export VPN3IT="${vpn3itRun}/bin/vpn3it-run"
    export VPN_HOST_FILE="${config.sops.secrets.vpn3ithost.path}"
    export ANDAMP_OVPN_FILE="${config.sops.secrets.andamp-vpn.path}"
    export ANDAMP_USER_FILE="${config.sops.secrets.andamp-vpn-user.path}"
    export ANDAMP_PASS_FILE="${config.sops.secrets.andamp-vpn-pass.path}"
    exec ${./doubletunnel.sh} "$@"
  '';

  vpn3it = pkgs.writeShellApplication {
    name = "vpn3it";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
      pkgs.gnused
      pkgs.iproute2
      pkgs.mosquitto
      pkgs.procps
      pkgs.systemd
    ];
    runtimeEnv =
      hubEnv
      // {
        VPN3IT_RUN = "${vpn3itRun}/bin/vpn3it-run";
      }
      // lib.optionalAttrs cfg.doubletunnel {
        DOUBLETUNNEL_RUN = "${doubletunnelRun}/bin/doubletunnel-run";
      }
      // lib.optionalAttrs (cfg.crdpPackage != null) {
        CRDP = "${cfg.crdpPackage}/bin/crdp";
      };
    excludeShellChecks = [ "SC2016" ];
    text = builtins.readFile ./vpn3it-cli.sh;
  };

  vpn3itToggle = pkgs.writeShellScriptBin "vpn3it-toggle" ''
    if ${vpn3it}/bin/vpn3it status | grep -qE '^this host: (connected|connecting)'; then
      exec ${vpn3it}/bin/vpn3it down
    fi
    exec ${vpn3it}/bin/vpn3it up
  '';

  vpn3itMutex = pkgs.writeShellApplication {
    name = "vpn3it-mutex";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.iproute2
      pkgs.jq
      pkgs.mosquitto
      pkgs.procps
    ];
    runtimeEnv.VPN3IT_PRIORITY = if cfg.vpn3itPriority then "1" else "0";
    text = builtins.readFile ./vpn3it-mutex.sh;
  };

  cfg = config.t3os.module.projects.andamp;
  bus = config.t3os.module.core.eventbus;
  host = config.t3os.whoami.host;
in
{
  config = lib.mkMerge [
    (lib.mkIf (cfg.CEFKM || cfg.CEIFRS || cfg.doubletunnel) {
      home.packages = [ vpn3it ];

      sops.secrets.vpn3ithost = {
        key = "vpn3ithost";
        sopsFile = ./secrets/secrets.json;
      };

      sops.secrets.vpn3ituser = {
        key = "vpn3ituser";
        sopsFile = ./secrets/secrets.json;
      };

      sops.secrets.vpn3itpass = {
        key = "vpn3itpass";
        sopsFile = ./secrets/secrets.json;
      };
    })
    (lib.mkIf ((cfg.CEFKM || cfg.CEIFRS || cfg.doubletunnel) && bus.enable) {
      systemd.user.services.vpn3it-mutex = {
        Unit.Description = "Publish the 3it VPN mutex state and release it when a priority host asks";
        Service = {
          ExecStart = lib.getExe vpn3itMutex;
          Restart = "always";
          RestartSec = "5s";
        };
        Install.WantedBy = [ "default.target" ];
      };
    })
    (lib.mkIf (cfg.CEFKM || cfg.CEIFRS) {
      home.packages = [ vpn3itToggle ];

      t3os.cli.scripts = [
        {
          command = [
            "settings"
            "vpn"
            "3it"
          ];
          title = "Connect to vpn3it VPN";
          script = "${vpn3itRun}/bin/vpn3it-run";
          usage = "Connect to vpn3it VPN. Prompts for Authy token only when needed.";
        }
      ];
    })
    (lib.mkIf cfg.doubletunnel {
      home.file.".claude/skills/doubletunnel/SKILL.md".source = ./doubletunnel-skill.md;

      t3os.cli.scripts = [
        {
          command = [ "settings" "vpn" "doubletunnel" ];
          title = "Connect to 3it through andamp";
          script = "${doubletunnelRun}/bin/doubletunnel-run";
          usage = "Connect the andamp VPN without taking the default route, then connect vpn3it through it. Prompts for the Authy token.";
        }
      ];
    })
  ];
}
