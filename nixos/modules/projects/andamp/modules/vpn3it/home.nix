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

  cfg = config.skynet.module.projects.andamp;
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
      skynet.cli.scripts = [
        {
          command = [
            "3it"
            "vpn"
          ];
          title = "Connect to vpn3it VPN";
          script = "${vpn3it}/bin/vpn3it";
          usage = "Connect to vpn3it VPN. Prompts for Authy token only when needed.";
        }
      ];
    })
    (lib.mkIf cfg.doubletunnel {
      skynet.cli.scripts = [
        {
          command = [ "doubletunnel" ];
          title = "Connect to 3it through andamp";
          script = "${doubletunnel}/bin/doubletunnel";
          usage = "Connect the andamp VPN without taking the default route, then connect vpn3it through it. Prompts for the Authy token.";
        }
      ];
    })
  ];
}
