{ ... }:
{
  imports = [
    ./bricky-userconfig.nix
    ../common.nix
  ];

  home = {
    username = "bricky";
    homeDirectory = "/home/bricky";

    stateVersion = "25.05";
  };

  nixpkgs.config.allowUnfree = true;

  programs.bash.bashrcExtra = ''
    [[ $- == *i* ]] && shopt -s xpg_echo
  '';
}
