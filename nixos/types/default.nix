{ lib, ... }:
{
  imports = [
    ./t3os-cli.nix
    ./t3os-host.nix
    ./t3os-modules.nix
    ./t3os-whoami.nix
  ];
}
