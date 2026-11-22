{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.t3os.module.desktop.stylix;
in
{
  config = lib.mkMerge [
    {
      programs.t3-desktop.stylix.enable = cfg.enable;
      stylix = {
        enable = lib.mkDefault true;
        base16Scheme = lib.mkDefault "${pkgs.base16-schemes}/share/themes/${cfg.scheme}.yaml";
        targets.rofi.enable = false;
      };
    }
    (lib.mkIf cfg.enable {
      t3os.cli.scripts = [
        {
          command = [
            "settings"
            "theme"
            "accent"
          ];
          title = "Show or change the accent colour";
          script = pkgs.writeShellScript "theme-accent.sh" ''
            set -euo pipefail
            host=${lib.escapeShellArg config.t3os.whoami.host}
            file="$HOME/repos/personal/dotfiles/nixos/config/hosts/$host/$host-hostconfig.nix"
            swatch() {
              local h=''${1#\#}
              printf '\033[48;2;%d;%d;%dm      \033[0m %s\n' 0x''${h:0:2} 0x''${h:2:2} 0x''${h:4:2} "#$h"
            }
            if [ $# -eq 0 ]; then
              swatch ${lib.escapeShellArg cfg.accent}
              exit 0
            fi
            new="''${1#\#}"
            if ! [[ "$new" =~ ^[0-9a-fA-F]{6}$ ]]; then
              echo "not a hex colour: $1 (want e.g. #1d9eb6)" >&2
              exit 1
            fi
            if [ "$(grep -cE 'accent = "#[0-9a-fA-F]{6}";' "$file")" != 1 ]; then
              echo "expected exactly one accent = \"#......\"; line in $file" >&2
              exit 1
            fi
            sed -i -E "s/accent = \"#[0-9a-fA-F]{6}\";/accent = \"#''${new,,}\";/" "$file"
            swatch "$new"
            read -rp "Rebuild now to apply? [Y/n] " ans
            case "''${ans:-y}" in
              [yY]*) exec t3os rebuild ;;
              *) echo "Saved to $file. Run t3os rebuild to apply." ;;
            esac
          '';
          usage = "Without an argument, shows the current accent. With one, e.g. `t3os settings theme accent #d65d0e`, writes it into this host's hostconfig and offers to rebuild. It colours window borders, tabs, the chrome and the t3os TUI.";
        }
      ];

      programs.t3-desktop.stylix = {
        scheme = cfg.scheme;
        accent = cfg.accent;
        ground = cfg.ground;
      };
    })
    (lib.mkIf (cfg.wallpaper != null) {
      programs.t3-desktop.wallpaper = cfg.wallpaper;
    })
  ];
}
