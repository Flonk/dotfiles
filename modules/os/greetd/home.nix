{
  config,
  lib,
  pkgs,
  ...
}:
let
  c = config.theme.color;
  mon = config.skynet.primaryMonitor;

  pythonEnv = pkgs.python3.withPackages (ps: [ ps.pygame ]);

  greeterAssets = pkgs.runCommand "skynet-greeter-preview-assets" { } ''
    mkdir -p $out
    cp ${./greeter.py} $out/greeter.py
    cp ${./mock-greetd.py} $out/mock-greetd.py
    ${lib.optionalString (builtins.pathExists config.theme.lockscreenImage) ''
      cp ${config.theme.lockscreenImage} $out/logo.png
    ''}
  '';

  greeterPreview = pkgs.writeShellScriptBin "skynet-greeter-preview" ''
    set -euo pipefail

    SOCK="/tmp/greetd-mock-$$.sock"
    trap 'kill %1 2>/dev/null; rm -f "$SOCK"' EXIT

    # Start mock greetd server in the background
    ${pythonEnv}/bin/python3 ${greeterAssets}/mock-greetd.py "$SOCK" &
    sleep 0.3

    # Run greeter in a Wayland window pointing at the mock socket
    export SDL_VIDEODRIVER=wayland
    export GREETD_SOCK="$SOCK"

    export GREETER_BG_COLOR="${c.app100}"
    export GREETER_BORDER_COLOR="${c.wm800}"
    export GREETER_TEXT_COLOR="${c.text}"
    export GREETER_TEXT_DIM="${c.app400}"
    export GREETER_BAR_BG="${c.app200}"
    export GREETER_BAR_FG="${c.app600}"
    export GREETER_BORDER_WIDTH="4"

    export GREETER_LOGO="${greeterAssets}/logo.png"
    export GREETER_FONT="${pkgs.dejavu_fonts}/share/fonts/truetype/DejaVuSansMono.ttf"
    export GREETER_FONT_BOLD="${pkgs.dejavu_fonts}/share/fonts/truetype/DejaVuSansMono-Bold.ttf"

    export GREETER_WIDTH="${toString mon.width}"
    export GREETER_HEIGHT="${toString mon.height}"

    export GREETER_DEFAULT_USER="flo"
    export GREETER_SESSION_CMD="Hyprland"

    ${pythonEnv}/bin/python3 ${greeterAssets}/greeter.py
  '';
in
{
  config =
    lib.mkIf (config.skynet.module.os.greetd.enable && config.skynet.module.os.greetd.greeter == "custom")
      {
        skynet.cli.scripts = [
          {
            command = [
              "greeter"
              "preview"
            ];
            title = "Preview greetd greeter";
            script = "${greeterPreview}/bin/skynet-greeter-preview";
            usage = "Preview your custom greeter in a Wayland window.";
          }
        ];
      };
}
