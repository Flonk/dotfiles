{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  sopsFile = ../modules/vpn3it/secrets/secrets.json;

  pkgs-2405 = import inputs.nixpkgs-2405 {
    system = pkgs.stdenv.hostPlatform.system;
  };

  rdp3it = pkgs.writeShellScriptBin "rdp3it" ''
    set -euo pipefail
    HOST="$(cat ${config.sops.secrets.rdp3ithost.path})"
    PORT="$(cat ${config.sops.secrets.rdp3itport.path})"
    USER="$(cat ${config.sops.secrets.rdp3ituser.path})"
    PASS="$(cat ${config.sops.secrets.rdp3itpass.path})"

    WIDTH="$(${pkgs.hyprland}/bin/hyprctl activewindow -j | ${pkgs.jq}/bin/jq -r '.size[0]')"
    HEIGHT="$(${pkgs.hyprland}/bin/hyprctl activewindow -j | ${pkgs.jq}/bin/jq -r '.size[1]')"

    RES="''${WIDTH}x''${HEIGHT}"

    ${pkgs-2405.freerdp}/bin/xfreerdp /v:"''${HOST}":"''${PORT}" /u:"''${USER}" /p:"''${PASS}" \
      /cert-ignore /bpp:32 /size:"''${RES}" \
      -gfx +rfx
  '';
in
{
  config = lib.mkIf config.skynet.module.projects.andamp.CEIFRS {
    wayland.windowManager.hyprland.settings.windowrule = [
      "float off, match:class xfreerdp"
    ];

    home.packages = [
      pkgs-2405.freerdp
    ];

    skynet.cli.scripts = [
      {
        command = [
          "3it"
          "rdp"
        ];
        title = "Connect to CEIFRS via RDP";
        script = "${rdp3it}/bin/rdp3it";
        usage = "Launch xfreerdp session to CEIFRS, sized to the active window.";

      }
    ];

    sops.secrets.rdp3ithost = {
      key = "rdp3ithost";
      inherit sopsFile;
    };

    sops.secrets.rdp3itport = {
      key = "rdp3itport";
      inherit sopsFile;
    };

    sops.secrets.rdp3ittitle = {
      key = "rdp3ittitle";
      inherit sopsFile;
    };

    sops.secrets.rdp3ituser = {
      key = "rdp3ituser";
      inherit sopsFile;
    };

    sops.secrets.rdp3itpass = {
      key = "rdp3itpass";
      inherit sopsFile;
    };
  };
}
