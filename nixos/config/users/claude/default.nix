{ ... }:
{
  imports = [
    ./claude-userconfig.nix
    ../common.nix
  ];

  home = {
    username = "claude";
    homeDirectory = "/home/claude";

    stateVersion = "24.11";
  };

  nixpkgs.config.allowUnfree = true;
}
