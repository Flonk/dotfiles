{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.skynet.module.desktop.i18n;

  skynet-i18n = pkgs.writeShellApplication {
    name = "skynet-i18n";
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
          echo "usage: skynet-i18n {status|current|list|set <im>|cycle}" >&2
          exit 2
          ;;
      esac
    '';
  };
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [ skynet-i18n ];
  };
}
