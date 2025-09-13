{
  pkgs,
  inputs,
  nix-colorizer,
  ...
}:
{
  imports = [
    ../config/types
    ../hosts/schnitzelwirt/schnitzelwirt-hostconfig.nix
    ../config/themes/trump/trump.nix
    ../users/flo.nix
  ];

  programs.zsh.shellAliases.nr = "(pkill walker || echo 0) && home-manager switch --impure --flake ~/dotfiles#flo-schnitzelwirt";
  programs.zsh.shellAliases.nrsys = "sudo nixos-rebuild switch --flake ~/dotfiles#schnitzelwirt";
}
