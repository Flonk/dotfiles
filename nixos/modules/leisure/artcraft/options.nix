{ lib, ... }:
let
  inherit (lib) mkOption types;
  app = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
  };
in
{
  options.t3os.module.leisure.artcraft = {
    photocraft = app;
    filmcraft = app;
    vectorcraft = app;
  };
}
