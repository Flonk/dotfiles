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

  vpn3it = pkgs.writeShellScriptBin "vpn3it" ''
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
    exec ${./vpn3it.sh} "$@"
  '';

  vpn3itToggle = pkgs.writeShellScriptBin "vpn3it-toggle" ''
    export PATH="${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.procps
        pkgs.systemd
      ]
    }:$PATH"
    emit() { command -v t3cron >/dev/null 2>&1 && t3cron emit "$@" --source vpn3it-toggle >/dev/null 2>&1 || true; }
    if systemctl --user is-active -q vpn3it-click || pgrep -x openconnect >/dev/null; then
      emit vpn3it/disconnecting info "Disconnecting the 3it VPN."
      systemctl --user stop vpn3it-click 2>/dev/null || sudo pkill -SIGINT openconnect
      exit 0
    fi
    token=$(vicinae-askpass "Authy token for 3it") || exit 0
    [ -n "$token" ] || exit 0
    file="''${XDG_RUNTIME_DIR:-/tmp}/vpn3it-token"
    (umask 077; printf '%s\n' "$token" > "$file")
    emit vpn3it/connecting info "Connecting the 3it VPN."
    systemctl --user reset-failed vpn3it-click 2>/dev/null || true
    systemd-run --user --unit=vpn3it-click --collect --setenv=PATH="$PATH" \
      sh -c 'tok=$(cat "$0"); rm -f "$0"; printf "%s\n" "$tok" | exec ${vpn3it}/bin/vpn3it' "$file" >/dev/null
  '';

  doubletunnel = pkgs.writeShellScriptBin "doubletunnel" ''
    export AWK="${pkgs.gawk}/bin/awk"
    export OPENVPN="${pkgs.openvpn}/bin/openvpn"
    export VPN3IT="${vpn3it}/bin/vpn3it"
    export VPN_HOST_FILE="${config.sops.secrets.vpn3ithost.path}"
    export ANDAMP_OVPN_FILE="${config.sops.secrets.andamp-vpn.path}"
    export ANDAMP_USER_FILE="${config.sops.secrets.andamp-vpn-user.path}"
    export ANDAMP_PASS_FILE="${config.sops.secrets.andamp-vpn-pass.path}"
    exec ${./doubletunnel.sh} "$@"
  '';

  cfg = config.t3os.module.projects.andamp;
in
{
  config = lib.mkMerge [
    (lib.mkIf (cfg.CEFKM || cfg.CEIFRS || cfg.doubletunnel) {
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
          script = "${vpn3it}/bin/vpn3it";
          usage = "Connect to vpn3it VPN. Prompts for Authy token only when needed.";
        }
      ];
    })
    (lib.mkIf cfg.doubletunnel {
      t3os.cli.scripts = [
        {
          command = [ "settings" "vpn" "doubletunnel" ];
          title = "Connect to 3it through andamp";
          script = "${doubletunnel}/bin/doubletunnel";
          usage = "Connect the andamp VPN without taking the default route, then connect vpn3it through it. Prompts for the Authy token.";
        }
      ];
    })
  ];
}
