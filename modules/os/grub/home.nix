{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  t = config.programs.skynetshell.theme;
  mon = config.skynet.host.primaryMonitor;

  grubPreview = pkgs.writeShellScriptBin "skynet-grub-preview" (''
    set -euo pipefail

    export GRUB_WIDTH="${toString mon.width}"
    export GRUB_HEIGHT="${toString mon.height}"
  '' + lib.optionalString (t != null) ''
    export GRUB_BG_COLOR="${t.bg_base}"
    export GRUB_BORDER_COLOR="${t.accent}"
    export GRUB_BAR_BG="${t.bg_active}"
    export GRUB_BAR_FG="${t.fg_secondary}"
    export GRUB_TEXT_COLOR="${t.fg_primary}"
    export GRUB_TEXT_DIM="${t.fg_muted}"
  '' + ''
    WORKDIR=$(mktemp -d)
    trap 'rm -rf "$WORKDIR"' EXIT
    cp -r ${inputs.skynetshell}/grub/. "$WORKDIR/"
    chmod -R u+w "$WORKDIR"

    exec ${pkgs.nix}/bin/nix-shell \
      -p imagemagick xorriso mtools grub2 qemu python3 OVMF.fd \
      --run "cd $WORKDIR && bash preview.sh"
  '');
in
{
  config = lib.mkIf config.skynet.module.os.grub.enable {
    skynet.cli.scripts = [
      {
        command = [
          "grub"
          "preview"
        ];
        title = "Preview GRUB theme in QEMU";
        script = "${grubPreview}/bin/skynet-grub-preview";
        usage = "Preview your custom GRUB theme in QEMU.";
      }
    ];
  };
}
