{ lib, ... }:
{
  imports = [
    ./skynet-cli.nix
    ./skynet-theme.nix
    ./skynet-host.nix
    ./skynet-modules.nix
  ];
}
