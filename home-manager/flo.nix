{ lib, pkgs, ... }:
{
  home = {
    packages = with pkgs; [
      hello
    ];

    # This needs to actually be set to your username
    username = "flo";
    homeDirectory = "/home/flo";

    stateVersion = "25.05";
  };
}
