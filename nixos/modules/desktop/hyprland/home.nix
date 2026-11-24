{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.t3os.module.desktop.hyprland;
  mon = config.t3os.host.primaryMonitor;
  display = pkgs.writeShellApplication {
    name = "t3os-display";
    runtimeInputs = with pkgs; [ config.wayland.windowManager.hyprland.finalPackage jq socat libnotify util-linux coreutils gnugrep ];
    runtimeEnv.T3OS_BIN = "${config.home.profileDirectory}/bin/t3os";
    text = builtins.readFile ./display.sh;
  };
  displayCommands = [
    { name = "status"; title = "Show connected displays and how they are arranged"; usage = "Lists every connected display (also switched-off ones) with mode, position and scale, the current mode (extend, mirror, internal, external) and whether a saved layout exists for this set of displays."; }
    { name = "extend"; title = "Extend the desktop onto external displays"; usage = "Turns every display on and places the external ones next to the laptop panel. Optional side: right (default), left, above, below. Example: t3os settings display extend left"; }
    { name = "mirror"; title = "Mirror one display onto all others"; usage = "Shows the same picture on every display. Mirrors the laptop panel by default, or pass a display name: t3os settings display mirror DP-2"; }
    { name = "internal"; title = "Use only the laptop panel"; usage = "Switches every external display off and keeps the laptop panel on."; }
    { name = "external"; title = "Use only the external displays"; usage = "Switches the laptop panel off and keeps every external display on, side by side."; }
    { name = "only"; title = "Use only one named display"; usage = "Keeps one display on and switches the rest off: t3os settings display only DP-2 (also accepts internal or external)."; }
    { name = "cycle"; title = "Cycle extend, mirror, external only, internal only"; usage = "Steps to the next arrangement, like Win+P. SUPER + P opens a picker instead."; }
    { name = "save"; title = "Remember the current arrangement for these displays"; usage = "Saves modes, positions, scale, rotation, mirroring and which displays are off, keyed by the set of connected displays (by name and model, not port). It is restored automatically whenever exactly these displays are plugged in again and after Hyprland reloads. Stored in ~/.config/t3os/displays.json."; }
    { name = "restore"; title = "Apply the saved arrangement for these displays"; usage = "Re-applies the layout saved with t3os settings display save for the displays currently connected."; }
    { name = "snapshot"; title = "Remember the current arrangement for one undo"; usage = "Stores the current layout in the runtime dir so t3os settings display undo can put it back. The SUPER + P picker does this before applying a choice."; }
    { name = "undo"; title = "Put back the arrangement from the last snapshot"; usage = "Re-applies the layout stored by t3os settings display snapshot, then forgets it. The SUPER + P picker runs this when a new layout is not confirmed within 15 seconds."; }
    { name = "forget"; title = "Forget the saved arrangement for these displays"; usage = "Deletes the saved layout for the current set of displays, so plugging them in falls back to Hyprland's defaults."; }
    { name = "profiles"; title = "List every saved display arrangement"; usage = "Shows each saved set of displays with when it was saved and how each display was set up."; }
  ];
in
{
  config = lib.mkIf (cfg.enable && config.programs.t3-desktop.hyprland.enable) {
    home.packages = [ display ];

    systemd.user.services.t3os-display = {
      Unit = {
        Description = "t3os display hotplug: restore saved monitor layouts";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${display}/bin/t3os-display _watch";
        Restart = "always";
        RestartSec = "3s";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    t3os.cli.scripts = map (d: {
      command = [ "settings" "display" d.name ];
      inherit (d) title usage;
      script = pkgs.writeShellScript "display-${d.name}.sh" ''
        exec ${display}/bin/t3os-display ${d.name} "$@"
      '';
    }) displayCommands ++ map (d: {
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
      hl.bind("SUPER + P", hl.dsp.exec_cmd("quickshell ipc call display toggle"))
      hl.monitor({ output = "eDP-1", mode = "${toString mon.width}x${toString mon.height}@${toString mon.hz}", position = "0x0", scale = 1.00 })
      hl.monitor({ output = "DP-2", mode = "5120x1440@120", position = "${toString mon.width}x0", scale = 1.00 })
    '';
  };
}
