{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.desktop.teams-jail.enable = mkOption {
    type = types.bool;
    default = false;
  };
}
