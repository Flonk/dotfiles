{
  config,
  lib,
  pkgs,
  ...
}:
let
  s = config.lib.stylix.colors.withHashtag;
  border = config.skynet.module.desktop.stylix.accent;
  mon = config.skynet.host.primaryMonitor;

  grubPreview = pkgs.writeShellScriptBin "skynet-grub-preview" ''
    set -euo pipefail

    export GRUB_BG_COLOR="${s.base00}"
    export GRUB_BORDER_COLOR="${border}"
    export GRUB_BAR_BG="${s.base01}"
    export GRUB_BAR_FG="${s.base04}"
    export GRUB_TEXT_COLOR="${s.base05}"
    export GRUB_TEXT_DIM="${s.base03}"
    export GRUB_WIDTH="${toString mon.width}"
    export GRUB_HEIGHT="${toString mon.height}"
    export GRUB_LOGO="${config.skynet.module.desktop.stylix.lockscreenImage}"

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
