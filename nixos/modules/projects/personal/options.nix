{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.t3os.module.projects.personal = {
    smallweb = {
      enable = mkOption {
        type = types.bool;
        default = false;
      };
      gopherHost = mkOption {
        type = types.str;
        default = "localhost";
      };
      geminiHost = mkOption {
        type = types.str;
        default = "localhost";
      };
    };
  };
}
