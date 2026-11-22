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
                description = "Human-readable title shown in the t3os TUI and --help";
              };
              script = mkOption {
                type = types.path;
                description = "Path to the script file (.sh)";
              };
              usage = mkOption {
                type = types.str;
                default = "";
                description = "Usage description shown in the t3os TUI detail pane";
              };
              pinned = mkOption {
                type = types.bool;
                default = false;
                description = "Pin the command to the top of the t3os TUI tree";
              };
              preview = mkOption {
                type = types.bool;
                default = false;
                description = "Run the command when the t3os TUI starts and show its output in the detail pane instead of the usage text; it must be quick and side-effect free";
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
