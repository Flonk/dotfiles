{ ... }:
{
  imports = [
    ./__USER__-userconfig.nix
    ../common.nix
  ];

  home = {
    username = "__USER__";
    homeDirectory = "/home/__USER__";

    stateVersion = "24.11";
  };

  nixpkgs.config.allowUnfree = true;
}
