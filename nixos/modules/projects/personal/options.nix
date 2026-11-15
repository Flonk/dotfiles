{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.projects.personal = {
    smallweb = {
      enable = mkOption {
        type = types.bool;
        default = false;
      };
      host = mkOption {
        type = types.str;
        default = "localhost";
      };
    };
  };
}
