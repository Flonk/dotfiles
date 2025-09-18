{
  pkgs,
  inputs,
  sops,
  config,
  ...
}:
{
  imports = [
    ../config/types
    ../hosts/schnitzelwirt/schnitzelwirt-hostconfig.nix
    ../config/themes/trump/trump.nix
    ./users/flo.nix
  ];

  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
  sops.age.generateKey = true;

  sops.secrets.andamp-vpn = {
    format = "binary";
    sopsFile = ../assets/secrets/andamp-vpn.ovpn;
  };

  sops.secrets.hello = {
    format = "yaml";
    sopsFile = ../assets/secrets/example.yaml;
  };

  systemd.user.services.import-andamp-vpn = {
    Unit = {
      Description = "Import andamp-vpn profile to NetworkManager (idempotent)";
      # You can't order a user unit After=NetworkManager.service (system unit).
      # If you want it at login, default.target is fine.
      After = [ "default.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = (
        pkgs.writeShellScript "import-andamp-vpn" ''
          set -euo pipefail
          NAME="andamp-vpn"
          if ! ${pkgs.networkmanager}/bin/nmcli -t -f NAME con show | grep -Fxq "$NAME"; then
            echo "Importing $NAME from ${config.sops.secrets.andamp-vpn.path}"
            exec ${pkgs.networkmanager}/bin/nmcli connection import type openvpn file "${config.sops.secrets.andamp-vpn.path}"
          else
            echo "$NAME already present; skipping import."
          fi
        ''
      );
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  programs.zsh.shellAliases.nr = "(pkill walker || echo 0) && home-manager switch --flake ~/dotfiles#flo-schnitzelwirt";
  programs.zsh.shellAliases.nrsys = "sudo nixos-rebuild switch --flake ~/dotfiles#schnitzelwirt";
}
