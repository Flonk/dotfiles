{
  config,
  lib,
  ...
}:
let
  cfg = config.skynet.module.desktop.hyprland;
  mon = config.skynet.host.primaryMonitor;
in
{
  config = lib.mkIf (cfg.enable && config.programs.gloxwald.hyprland.enable) {
    wayland.windowManager.hyprland.settings = {
      config.input.kb_layout = "de";

      env = map (e: { _args = e; }) [
        [ "NIXOS_OZONE_WL" "1" ]
        [ "NIXPKGS_ALLOW_UNFREE" "1" ]
        [ "GDK_BACKEND" "wayland,x11" ]
        [ "CLUTTER_BACKEND" "wayland" ]
        [ "QT_QPA_PLATFORM" "wayland;xcb" ]
        [ "QT_WAYLAND_DISABLE_WINDOWDECORATION" "1" ]
        [ "QT_AUTO_SCREEN_SCALE_FACTOR" "1" ]
        [ "MOZ_ENABLE_WAYLAND" "1" ]
        [ "AQ_DRM_DEVICES" "/dev/dri/card0:/dev/dri/card1" ]
        [ "GDK_SCALE" "1" ]
        [ "QT_SCALE_FACTOR" "1" ]
        [ "EDITOR" "micro" ]
        [ "HYPRSHOT_DIR" "${config.home.homeDirectory}/Pictures/Screenshots" ]
      ];

      window_rule = [
        { match.class = "^(Alacritty|code)$";                            opacity = "1 1"; }
        { match = { class = "Alacritty"; title = "^(initial-shell)$"; }; size = "500 100"; }
        { match.class = "^chrome-nngceckbapebfimnlniiiahkandclblb.*$";   float = true; }
      ];
    };

    wayland.windowManager.hyprland.extraConfig = ''
      hl.monitor({ output = "eDP-1", mode = "${toString mon.width}x${toString mon.height}@${toString mon.hz}", position = "0x0", scale = 1.00 })
      hl.monitor({ output = "DP-2", mode = "5120x1440@120", position = "${toString mon.width}x0", scale = 1.00 })
    '';
  };
}
