{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.t3os.module.development.obsidian = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
    ui.enable = mkOption {
      type = types.bool;
      default = false;
      description = "Install the Obsidian desktop GUI (requires enable = true).";
    };
  };
}
