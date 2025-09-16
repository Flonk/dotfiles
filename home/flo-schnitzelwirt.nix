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
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
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
      Description = "Import andamp-vpn profile to NetworkManager";
      After = [ "network-manager.service" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = ''${pkgs.networkmanager}/bin/nmcli connection import type openvpn file ${config.sops.secrets.andamp-vpn.path}'';
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  programs.zsh.shellAliases.nr = "home-manager switch --flake ~/dotfiles#flo-schnitzelwirt";
  programs.zsh.shellAliases.nrsys = "sudo nixos-rebuild switch --flake ~/dotfiles#schnitzelwirt";
}
