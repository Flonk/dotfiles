{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.programs.gloxwald.i18n;

  imItems = lib.listToAttrs (
    lib.imap0 (
      i: m:
      lib.nameValuePair "Groups/0/Items/${toString i}" (
        {
          Name = m.im;
        }
        // lib.optionalAttrs (m.layout != "") { Layout = m.layout; }
      )
    ) cfg.inputMethods
  );

  gloxwald-i18n = pkgs.writeShellApplication {
    name = "gloxwald-i18n";
    runtimeInputs = [ config.i18n.inputMethod.package ];
    text = ''
      ims=(${lib.concatMapStringsSep " " (m: lib.escapeShellArg m.im) cfg.inputMethods})
      labels=(${lib.concatMapStringsSep " " (m: lib.escapeShellArg m.label) cfg.inputMethods})

      find_index() {
        local i
        for i in "''${!ims[@]}"; do
          if [ "''${ims[$i]}" = "$1" ]; then
            echo "$i"
            return 0
          fi
        done
        return 1
      }

      case "''${1:-}" in
        status)
          cur="$(fcitx5-remote -n)"
          if idx="$(find_index "$cur")"; then
            echo "''${labels[$idx]}"
          else
            echo "$cur" | tr '[:lower:]' '[:upper:]'
          fi
          ;;
        current)
          fcitx5-remote -n
          ;;
        list)
          for i in "''${!ims[@]}"; do
            printf '%s\t%s\n' "''${ims[$i]}" "''${labels[$i]}"
          done
          ;;
        set)
          fcitx5-remote -s "''${2:?input method name required}"
          ;;
        cycle)
          cur="$(fcitx5-remote -n)"
          idx="$(find_index "$cur")" || idx=-1
          next=$(((idx + 1) % ''${#ims[@]}))
          fcitx5-remote -s "''${ims[$next]}"
          ;;
        *)
          echo "usage: gloxwald-i18n {status|current|list|set <im>|cycle}" >&2
          exit 2
          ;;
      esac
    '';
  };
in
{
  options.programs.gloxwald.i18n = {
    enable = lib.mkEnableOption "fcitx5 input-method switching (gloxwald-i18n CLI, bar widget, MOD3+I cycle)";

    defaultLayout = lib.mkOption {
      type = lib.types.str;
      default = "us";
    };

    inputMethods = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            im = lib.mkOption { type = lib.types.str; };
            label = lib.mkOption { type = lib.types.str; };
            layout = lib.mkOption {
              type = lib.types.str;
              default = "";
            };
          };
        }
      );
      default = [
        {
          im = "keyboard-us";
          label = "ENGLISH";
        }
      ];
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        home.packages = [ gloxwald-i18n ];

        i18n.inputMethod = {
          enable = true;
          type = "fcitx5";
          fcitx5 = {
            waylandFrontend = true;
            addons = with pkgs; [
              qt6Packages.fcitx5-chinese-addons
              fcitx5-gtk
            ];
            settings.globalOptions."Hotkey/TriggerKeys" = { };
            settings.inputMethod = {
              GroupOrder."0" = "Default";
              "Groups/0" = {
                Name = "Default";
                "Default Layout" = cfg.defaultLayout;
                DefaultIM = (builtins.head cfg.inputMethods).im;
              };
            }
            // imItems;
          };
        };
      }

      (lib.mkIf config.programs.gloxwald.hyprland.enable {
        wayland.windowManager.hyprland.extraConfig = ''
          hl.bind("MOD3 + I", hl.dsp.exec_cmd("gloxwald-i18n cycle"))
        '';
      })
    ]
  );
}
