{ lib, ... }:
{
  imports = [
    ./skynet-cli.nix
    ./skynet-host.nix
    ./skynet-modules.nix
  ];
}
