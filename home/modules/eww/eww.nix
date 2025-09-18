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
  # Windows now live under ./windows, with bar aggregating left/right/center
  bar = import ./windows/bar.nix { monitor = cfg.monitor; };
  system = import ./modules/system.nix { };
  cal = import ./modules/cal.nix { };
  audio = import ./modules/audio.nix { };
  music_pop = import ./modules/music_pop.nix { };

  # List of all module records (some may not export scripts)
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
    # left/right/center merged into bar
    bar
    system
    cal
    audio
    music_pop
  ];

  # Collect scripts from modules that export them
  moduleScripts = builtins.concatLists (map (m: m.scripts or [ ]) modulesList);

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
    system.yuck
    cal.yuck
    audio.yuck
    music_pop.yuck
    # left/right/center are included by bar
    bar.yuck
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
    # Ensure runtime dependencies for scripts/widgets are present
    home.packages = with pkgs; [
      eww
      brightnessctl
      playerctl
      jq
      networkmanager # provides nmcli
      upower
      alsa-utils
    ];

    # Build script attrset from scripts provided by modules
    xdg.configFile =
      let
        scriptAttrs = builtins.listToAttrs (
          map (s: {
            name = s.path;
            value = {
              text = s.text;
              executable = true;
            };
          }) moduleScripts
        );
      in
      scriptAttrs
      // {
        # Main files
        "eww/eww.yuck".text = yuckAll;
        "eww/eww.scss".text = scssAll;

        # Placeholder assets to avoid missing images errors
        "eww/images/.keep".text = "";
      };

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
