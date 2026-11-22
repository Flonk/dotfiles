{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.t3os = {
    cli = {
      fzfThemeArgs = mkOption {
        type = types.str;
        default = "";
        description = "Common fzf theme args (style + colors) set by t3os-scripts module";
      };

      scripts = mkOption {
        type = types.listOf (
          types.submodule {
            options = {
              command = mkOption {
                type = types.listOf types.str;
                description = "Command path, e.g. ['fingerprint' 'enroll'] becomes `t3os fingerprint enroll`";
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
        description = "Scripts registered by modules, collected into the t3os CLI";
      };

      updaters = mkOption {
        type = types.listOf (
          types.submodule {
            options = {
              name = mkOption {
                type = types.str;
                description = "Name shown while `t3os upgrade` runs this updater";
              };
              script = mkOption {
                type = types.path;
                description = "Script that bumps pinned versions in the repo; runs with T3OS_REPO set to the dotfiles checkout";
              };
            };
          }
        );
        default = [ ];
        description = "Updaters registered by modules, run by `t3os upgrade` after `nix flake update`";
      };
    };
  };
}
