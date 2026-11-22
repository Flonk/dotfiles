{
  config,
  lib,
  pkgs,
  ...
}:
let
  i18n = "${config.home.profileDirectory}/bin/t3-desktop-i18n";
in
{
  imports = [ ./vicinae.nix ];

  config = lib.mkIf config.t3os.module.desktop.i18n.enable {
    programs.t3-desktop.i18n = {
      enable = true;
      defaultLayout = "de";
      inputMethods = [
        {
          im = "keyboard-de";
          label = "GERMAN";
        }
        {
          im = "pinyin";
          label = "CHINESE";
        }
      ];
    };

    t3os.cli.scripts = [
      {
        command = [
          "settings"
          "language"
          "list"
        ];
        title = "List input methods";
        script = pkgs.writeShellScript "language-list.sh" ''
          set -euo pipefail
          cur=$(${i18n} current)
          ${i18n} list | while IFS=$'\t' read -r im label; do
            if [ "$im" = "$cur" ]; then mark="▸"; else mark=" "; fi
            printf '%s %-14s %s\n' "$mark" "$im" "$label"
          done
        '';
        usage = "Lists the fcitx5 input methods you can switch between and marks the active one.";
      }
      {
        command = [
          "settings"
          "language"
          "cycle"
        ];
        title = "Switch to the next input method";
        script = pkgs.writeShellScript "language-cycle.sh" ''
          set -euo pipefail
          ${i18n} cycle
          ${i18n} status
        '';
        usage = "Cycles German → Chinese pinyin → German and prints the new one.";
      }
      {
        command = [
          "settings"
          "language"
          "set"
        ];
        title = "Switch to a specific input method";
        script = pkgs.writeShellScript "language-set.sh" ''
          set -euo pipefail
          ${i18n} set "''${1:?usage: t3os settings language set <im> (see t3os settings language list)}"
          ${i18n} status
        '';
        usage = "Usage: `t3os settings language set <im>`, e.g. `keyboard-de` or `pinyin`.";
      }
    ];
  };
}
