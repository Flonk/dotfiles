{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet = {
    cli = {
      fzfThemeArgs = mkOption {
        type = types.str;
        default = "";
        description = "Common fzf theme args (style + colors) set by skynet-scripts module";
      };

      scripts = mkOption {
        type = types.listOf (
          types.submodule {
            options = {
              command = mkOption {
                type = types.listOf types.str;
                description = "Command path, e.g. ['fingerprint' 'enroll'] becomes `skynet fingerprint enroll`";
              };
              title = mkOption {
                type = types.str;
                description = "Human-readable title shown in fzf selection list";
              };
              script = mkOption {
                type = types.path;
                description = "Path to the script file (.sh)";
              };
              usage = mkOption {
                type = types.str;
                default = "";
                description = "Usage description shown below the ASCII art in preview";
              };
            };
          }
        );
        default = [ ];
        description = "Scripts registered by modules, collected into the skynet CLI";
      };
    };
  };
}
