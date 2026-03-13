{
  config,
  lib,
  pkgs,
  ...
}:
let
  c = config.skynet.theme.color;
  mon = config.skynet.host.primaryMonitor;

  grubPreview = pkgs.writeShellScriptBin "skynet-grub-preview" ''
    set -euo pipefail

    export GRUB_BG_COLOR="${c.app100}"
    export GRUB_BORDER_COLOR="${c.wm800}"
    export GRUB_BAR_BG="${c.app200}"
    export GRUB_BAR_FG="${c.app600}"
    export GRUB_TEXT_COLOR="${c.text}"
    export GRUB_TEXT_DIM="${c.app400}"
    export GRUB_WIDTH="${toString mon.width}"
    export GRUB_HEIGHT="${toString mon.height}"
    export GRUB_LOGO="${config.skynet.theme.lockscreenImage}"

    WORKDIR=$(mktemp -d)
    trap 'rm -rf "$WORKDIR"' EXIT
    cp -r ${./src}/. "$WORKDIR/"
    chmod -R u+w "$WORKDIR"

    exec ${pkgs.nix}/bin/nix-shell \
      -p imagemagick xorriso mtools grub2 qemu python3 OVMF.fd \
      --run "cd $WORKDIR && bash preview.sh"
  '';
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
