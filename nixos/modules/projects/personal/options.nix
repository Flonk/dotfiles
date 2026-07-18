{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.projects.personal = {
    dwain = {
      enable = mkOption {
        type = types.bool;
        default = false;
      };
    };
  };
}
