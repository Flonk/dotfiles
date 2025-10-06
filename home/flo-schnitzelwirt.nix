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
    ./modules/work/andamp.nix
  ];

  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
  sops.age.generateKey = true;

  programs.zsh.shellAliases.nr = "(pkill walker || echo 0) && home-manager switch --flake ~/dotfiles#flo-schnitzelwirt";
  programs.zsh.shellAliases.nrsys = "sudo nixos-rebuild switch --flake ~/dotfiles#schnitzelwirt";
}
