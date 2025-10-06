{ pkgs, config, ... }:
{
  sops.secrets.andamp-vpn = {
    format = "binary";
    sopsFile = ../../../assets/secrets/andamp-vpn.ovpn;
  };

  systemd.user.services.import-andamp-vpn = {
    Unit = {
      Description = "Import andamp-vpn profile to NetworkManager (idempotent)";
      After = [ "default.target" ];
      ConditionPathExists = "${config.sops.secrets.andamp-vpn.path}";
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = (
        pkgs.writeShellScript "import-andamp-vpn" ''
          set -euo pipefail
          NAME="andamp-vpn"
          # Check if connection already exists (using grep -q with just -F, not -x)
          if ${pkgs.networkmanager}/bin/nmcli -t -f NAME con show | grep -Fq "$NAME"; then
            echo "$NAME already present; skipping import."
            exit 0
          fi
          echo "Importing $NAME from ${config.sops.secrets.andamp-vpn.path}"
          ${pkgs.networkmanager}/bin/nmcli connection import type openvpn file "${config.sops.secrets.andamp-vpn.path}"
        ''
      );
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
