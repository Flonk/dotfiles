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
      (box :orientation "h" :space-evenly false :halign "end" :class "left_modules"
        (bright)
        (volume)
        (wifi)
        (sep)
        (bat)
        (mem)
        (sep)
        (clock_module)
        (music)))

    (defwidget right []
      (box :orientation "h" :space-evenly false :halign "start" :class "right_modules"
        (workspaces)))

    (defwidget center []
      (box :orientation "h" :space-evenly false :halign "center" :class "center_modules"
        (clock_module)))

    (defwidget bar_1 []
      (box :class "bar_class" :orientation "h" (left) (center) (right)))

    (defwindow bar
      :geometry (geometry :x "0%" :y "0" :width "100%" :height "30px" :anchor "top center")
      :stacking "fg" :windowtype "dock" :monitor "${monitor}"
      (bar_1))
  '';

  barScss = ''
    .bar_class { background-color: #0f0f17; border-radius: 16px; }
  '';

  inherit (lib) concatStrings;

  yuckAll = concatStrings [
    base.yuck
    wifi.yuck
    workspaces.yuck
    battery.yuck
    memory.yuck
    sep.yuck
    clock.yuck
    volume.yuck
    bright.yuck
    music.yuck
    system.yuck
    cal.yuck
    audio.yuck
    music_pop.yuck
    barWidgetsYuck
  ];

  scssAll = concatStrings [
    base.scss
    barScss
    wifi.scss
    clock.scss
    memory.scss
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
  ];

  scriptsAll = builtins.concatLists (map (m: m.scripts or [ ]) modulesList);

in
{
  yuck = yuckAll;
  scss = scssAll;
  scripts = scriptsAll;
}
