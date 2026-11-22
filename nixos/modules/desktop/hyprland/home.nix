{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.t3os.module.desktop.hyprland;
  mon = config.t3os.host.primaryMonitor;
in
{
  config = lib.mkIf (cfg.enable && config.programs.t3-desktop.hyprland.enable) {
    t3os.cli.scripts = map (d: {
      command = [
        "settings"
        "display"
        "scale"
        d.name
      ];
      inherit (d) title usage;
      script = pkgs.writeShellScript "display-scale-${d.name}.sh" ''
        exec ${config.home.profileDirectory}/bin/hypr-scale ${d.name}
      '';
    }) [
      {
        name = "up";
        title = "Make everything bigger on the focused monitor";
        usage = "Steps the focused monitor's scale up one rung (0.8, 1.0, 1.25, 1.67, 2.0, 2.5). Same as SUPER + plus.";
      }
      {
        name = "down";
        title = "Make everything smaller on the focused monitor";
        usage = "Steps the focused monitor's scale down one rung. Same as SUPER + minus.";
      }
      {
        name = "reset";
        title = "Reset the focused monitor to scale 1";
        usage = "Sets the focused monitor back to scale 1.0. Same as SUPER + CTRL + 0.";
      }
    ];

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
