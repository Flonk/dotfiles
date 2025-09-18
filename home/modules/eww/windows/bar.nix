{
  lib,
  pkgs,
  config,
  monitor ? "eDP-1",
}:
let
  # Import module fragments
  base = import ../modules/base.nix { inherit lib pkgs config; };
  wifi = import ../modules/wifi.nix { inherit lib pkgs config; };
  workspaces = import ../modules/workspaces.nix { inherit lib pkgs config; };
  battery = import ../modules/battery.nix { inherit lib pkgs config; };
  memory = import ../modules/memory.nix { inherit lib pkgs config; };
  sep = import ../modules/sep.nix { inherit lib pkgs config; };
  clock = import ../modules/clock.nix { inherit lib pkgs config; };
  volume = import ../modules/volume.nix { inherit lib pkgs config; };
  bright = import ../modules/bright.nix { inherit lib pkgs config; };
  music = import ../modules/music.nix { inherit lib pkgs config; };
  system = import ../modules/system.nix { inherit lib pkgs config; };
  cal = import ../modules/cal.nix { inherit lib pkgs config; };
  audio = import ../modules/audio.nix { inherit lib pkgs config; };
  music_pop = import ../modules/music_pop.nix { inherit lib pkgs config; };

  modulesList = [
    base
    wifi
    workspaces
    battery
    memory
    sep
    clock
    volume
    bright
    music
    system
    cal
    audio
    music_pop
  ];

  barWidgetsYuck = ''
    (defwidget left []
      (box :orientation "h" :space-evenly false :halign "start" :class "left_modules"
        (bright)
        (volume)
        (wifi)
        (sep)
        (bat)
        (sep)
        (music)
        (workspaces)))

    (defwidget noright []
      (box :orientation "h" :space-evenly false :halign "start" :class "right_modules"
        ))

    (defwidget right []
      (box :orientation "h" :space-evenly false :halign "end" :class "right_modules"
        (clock_module)
        (mem)))

    (defwidget center []
      (box :orientation "h" :space-evenly false :halign "center" :class "center_modules"
        (mem)))

    (defwidget bar_1 []
      (box :class "bar_class" :orientation "h" (center) (right)))

    (defwindow bar
      :geometry (geometry :x "0%" :y "0" :width "100%" :height "30px" :anchor "top center")
      :stacking "fg" :windowtype "dock" :monitor "${monitor}"
      (bar_1))
  '';

  barScss = ''
    .bar_class {
      background-color: ${config.theme.color.app150};
      color: ${config.theme.color.app600};
    }
  '';

  # Use a newline as the joiner when concatenating strings in this file
  concatStrings = lib.concatStringsSep "\n";

  yuckAll = concatStrings [
    /*
      wifi.yuck
      workspaces.yuck
      battery.yuck
      sep.yuck
      volume.yuck
      bright.yuck
      music.yuck
      system.yuck
      cal.yuck
      audio.yuck
      music_pop.yuck
    */
    base.yuck
    clock.yuck
    memory.yuck
    barWidgetsYuck
  ];

  scssAll = concatStrings [
    /*
      wifi.scss
      battery.scss
      bright.scss
      volume.scss
      sep.scss
      workspaces.scss
      music.scss
      cal.scss
      system.scss
      music_pop.scss
      audio.scss
    */
    base.scss
    barScss
    memory.scss
    clock.scss
  ];

  scriptsAll = builtins.concatLists (map (m: m.scripts or [ ]) modulesList);

in
{
  yuck = yuckAll;
  scss = scssAll;
  scripts = scriptsAll;
}
