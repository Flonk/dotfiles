{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.skynet.module.projects.andamp;
in
{
  imports = [
    ./CEFKM/home.nix
    ./CEIFRS/home.nix
    ./modules/vpn3it/home.nix
  ];

  config = lib.mkMerge [
    (lib.mkIf (cfg.enable || cfg.doubletunnel) {
      sops.secrets.andamp-vpn = {
        format = "binary";
        sopsFile = ./secrets/andamp-vpn.ovpn;
      };

      sops.secrets.andamp-vpn-user = {
        sopsFile = ./secrets/andamp-vpn-auth.json;
      };

      sops.secrets.andamp-vpn-pass = {
        sopsFile = ./secrets/andamp-vpn-auth.json;
      };
    })
    (lib.mkIf cfg.enable {
      systemd.user.services.import-andamp-vpn = {
        Unit = {
          Description = "Import andamp-vpn profile to NetworkManager (idempotent)";
          After = [
            "default.target"
            "sops-nix.service"
          ];
          ConditionPathExists = [
            "${config.sops.secrets.andamp-vpn.path}"
            "${config.sops.secrets.andamp-vpn-user.path}"
            "${config.sops.secrets.andamp-vpn-pass.path}"
          ];
        };
        Service = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = (
            pkgs.writeShellScript "import-andamp-vpn" ''
              set -euo pipefail
              NAME="andamp-vpn"
              NMCLI="${pkgs.networkmanager}/bin/nmcli"
              if $NMCLI -t -f NAME con show | ${pkgs.gnugrep}/bin/grep -Fxq "$NAME"; then
                echo "$NAME already present; skipping import."
              else
                echo "Importing $NAME from ${config.sops.secrets.andamp-vpn.path}"
                $NMCLI connection import type openvpn file "${config.sops.secrets.andamp-vpn.path}"
              fi
              $NMCLI connection modify "$NAME" \
                +vpn.data "username=$(cat "${config.sops.secrets.andamp-vpn-user.path}")" \
                +vpn.data "password-flags=0" \
                vpn.secrets "password=$(cat "${config.sops.secrets.andamp-vpn-pass.path}")"
            ''
          );
        };
        Install = {
          WantedBy = [ "default.target" ];
        };
      };
    })
  ];
}
