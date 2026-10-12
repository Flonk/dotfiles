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

  workspaces = {
    rf-test = "dtbxrftest";
    rf-preprod = "dtbxrfpreprod";
    rf-prod = "dtbxrfprod";
    ifrs-preprod = "dtbxifrspreprod";
    ifrs-prod = "dtbxifrsprod";
    adf-prod = "rfadfprod";
  };

  crdp = pkgs.buildNpmPackage {
    pname = "crdp";
    version = "1.0.0";
    src = ./crdp;
    npmDepsHash = "sha256-6oMU3oGPXJH6LsClNQC/lxV6fJUW3Jr7GE8WJMmBVaQ=";

    nativeBuildInputs = [ pkgs.makeWrapper ];

    postInstall = ''
      makeWrapper ${pkgs.nodejs}/bin/node $out/bin/crdp \
        --add-flags $out/lib/node_modules/crdp/dist/main.js \
        --set CRDP_HOST_FILE ${config.sops.secrets.rdp3ithost.path} \
        --set CRDP_PORT_FILE ${config.sops.secrets.rdp3itport.path} \
        --set CRDP_USER_FILE ${config.sops.secrets.rdp3ituser.path} \
        --set CRDP_PASS_FILE ${config.sops.secrets.rdp3itpass.path} \
        --set CRDP_WORKSPACES ${
          lib.escapeShellArg (
            builtins.toJSON (lib.mapAttrs (_: key: config.sops.secrets.${key}.path) workspaces)
          )
        } \
        --prefix PATH : ${
          lib.makeBinPath [
            pkgs-2405.freerdp
            pkgs.procps
            pkgs.xdotool
            pkgs.xinput
            pkgs.xclip
            pkgs.wl-clipboard
            pkgs.imagemagick
          ]
        }
    '';
  };
in
{
  config = lib.mkIf config.skynet.module.projects.andamp.CEIFRS {
    wayland.windowManager.hyprland.settings.window_rule = [
      { match.class = "xfreerdp"; float = false; }
      { match.tag = "crdp-locked"; border_color = "rgb(FF0000) rgb(880808)"; }
    ];

    home.packages = [
      pkgs-2405.freerdp
      crdp
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

    sops.secrets = lib.genAttrs (
      [
        "rdp3ithost"
        "rdp3itport"
        "rdp3ittitle"
        "rdp3ituser"
        "rdp3itpass"
      ]
      ++ lib.attrValues workspaces
    ) (key: { inherit key sopsFile; });
  };
}
