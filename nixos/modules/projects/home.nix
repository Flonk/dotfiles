{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./andamp/home.nix
    ./personal/home.nix
  ];
}
