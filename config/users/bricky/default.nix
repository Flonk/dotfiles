{
  config,
  lib,
  pkgs,
  self,
  theme,
  inputs,
  ...
}:
{
  imports = [
    ./bricky-userconfig.nix
    ../common.nix
  ];

  home = {
    packages = with pkgs; [
      nixfmt
      jq
      btop
      tree
    ];

    username = "bricky";
    homeDirectory = "/home/bricky";

    stateVersion = "25.05";
  };

  nixpkgs.config.allowUnfree = true;

  programs.bash.bashrcExtra = ''
    [[ $- == *i* ]] && shopt -s xpg_echo
  '';

  programs.eza.enable = true;
  programs.bat.enable = true;
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };
}
