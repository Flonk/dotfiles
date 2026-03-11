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
    ./zeroclaw-userconfig.nix
    ../common.nix
  ];

  home = {
    packages = [ ];

    username = "zeroclaw";
    homeDirectory = "/home/zeroclaw";

    stateVersion = "25.05";
  };

  nixpkgs.config.allowUnfree = true;

  programs.bash.bashrcExtra = ''
    [[ $- == *i* ]] && shopt -s xpg_echo
  '';

}
