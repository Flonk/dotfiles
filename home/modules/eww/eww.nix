{
  pkgs,
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    concatStrings
    concatMapStringsSep
    ;

  cfg = config.programs.ewwBar;

  # Import module fragments
  base = import ./modules/base.nix { inherit lib pkgs config; };
  wifi = import ./modules/wifi.nix { inherit lib; };
  workspaces = import ./modules/workspaces.nix { };
  battery = import ./modules/battery.nix { };
  memory = import ./modules/memory.nix { };
  sep = import ./modules/sep.nix { };
  clock = import ./modules/clock.nix { };
  volume = import ./modules/volume.nix { };
  bright = import ./modules/bright.nix { };
  music = import ./modules/music.nix { };
  left = import ./modules/left.nix { };
  right = import ./modules/right.nix { };
  center = import ./modules/center.nix { };
  bar = import ./modules/bar.nix { monitor = cfg.monitor; };
  system = import ./modules/system.nix { };
  cal = import ./modules/cal.nix { };
  audio = import ./modules/audio.nix { };
  music_pop = import ./modules/music_pop.nix { };

  # Order of yuck parts
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
    left.yuck
    right.yuck
    center.yuck
    bar.yuck
    system.yuck
    cal.yuck
    audio.yuck
    music_pop.yuck
  ];

  # Order of scss parts
  scssAll = concatStrings [
    base.scss
    bar.scss
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

in
{
  options.programs.ewwBar = {
    enable = mkEnableOption "Eww bar";
    monitor = mkOption {
      type = types.str;
      default = "eDP-1";
      description = "Monitor name to bind the bar window to.";
    };
  };

  config = mkIf cfg.enable {
    xdg.configFile."eww/eww.yuck".text = yuckAll;
    xdg.configFile."eww/eww.scss".text = scssAll;

    systemd.user.services.eww-daemon = {
      Unit = {
        Description = "Eww daemon";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.eww-wayland}/bin/eww daemon";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    systemd.user.services.eww-bar = {
      Unit = {
        Description = "Open Eww bar";
        After = [ "eww-daemon.service" ];
        Requires = [ "eww-daemon.service" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.eww-wayland}/bin/eww open bar";
        ExecStop = "${pkgs.eww-wayland}/bin/eww close bar";
        RemainAfterExit = true;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
