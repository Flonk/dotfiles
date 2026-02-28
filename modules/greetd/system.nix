{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.skynet.module.greetd;
  c = config.theme.color;
  mon = config.skynet.primaryMonitor;
  isCustom = cfg.greeter == "custom";

  pythonEnv = pkgs.python3.withPackages (ps: [ ps.pygame ]);

  greeterAssets = pkgs.runCommand "skynet-greeter-assets" { } ''
    mkdir -p $out
    cp ${./greeter.py} $out/greeter.py
    ${lib.optionalString (builtins.pathExists config.theme.lockscreenImage) ''
      cp ${config.theme.lockscreenImage} $out/logo.png
    ''}
  '';

  skynetGreeter = pkgs.writeShellScriptBin "skynet-greeter" ''
    set -euo pipefail

    # SDL backend for rendering without a compositor
    export SDL_VIDEODRIVER="''${SDL_VIDEODRIVER:-kmsdrm}"

    # Theme colors
    export GREETER_BG_COLOR="${c.app100}"
    export GREETER_BORDER_COLOR="${c.wm800}"
    export GREETER_TEXT_COLOR="${c.text}"
    export GREETER_TEXT_DIM="${c.app400}"
    export GREETER_BAR_BG="${c.app200}"
    export GREETER_BAR_FG="${c.app600}"
    export GREETER_BORDER_WIDTH="4"

    # Paths
    export GREETER_LOGO="${greeterAssets}/logo.png"
    export GREETER_FONT="${pkgs.dejavu_fonts}/share/fonts/truetype/DejaVuSansMono.ttf"
    export GREETER_FONT_BOLD="${pkgs.dejavu_fonts}/share/fonts/truetype/DejaVuSansMono-Bold.ttf"

    # Screen
    export GREETER_WIDTH="${toString mon.width}"
    export GREETER_HEIGHT="${toString mon.height}"

    # Defaults
    export GREETER_DEFAULT_USER="flo"
    export GREETER_SESSION_CMD="Hyprland"

    exec ${pythonEnv}/bin/python3 ${greeterAssets}/greeter.py
  '';

  greeterCommand =
    if isCustom then
      "${skynetGreeter}/bin/skynet-greeter"
    else
      "${pkgs.tuigreet}/bin/tuigreet --time --cmd Hyprland";
in
{
  config = lib.mkIf cfg.enable {
    services.greetd = {
      enable = true;
      settings = {
        default_session = {
          command = greeterCommand;
          user = "flo";
        };
      };
    };

    # Make sure greetd user can access DRM/KMS devices (needed for custom greeter)
    users.users.greeter = lib.mkIf isCustom {
      isSystemUser = true;
      group = "greeter";
      extraGroups = [
        "video"
        "render"
        "input"
      ];
    };
    users.groups.greeter = lib.mkIf isCustom { };

    systemd.services.greetd.serviceConfig = {
      Type = "idle";
      StandardInput = "tty";
      StandardOutput = "tty";
      StandardError = "journal"; # Without this errors will spam on screen
      # Without these bootlogs will spam on screen
      TTYReset = true;
      TTYVHangup = true;
      TTYVTDisallocate = true;
    };
  };
}
