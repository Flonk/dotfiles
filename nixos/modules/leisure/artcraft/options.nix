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
  options.skynet.module.leisure.artcraft = {
    photocraft = app;
    filmcraft = app;
    vectorcraft = app;
  };
}
