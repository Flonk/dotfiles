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

  # Only import the bar, which now aggregates everything
  bar = import ./windows/bar.nix {
    inherit lib pkgs config;
    monitor = cfg.monitor;
  };

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
    home.packages = with pkgs; [
      eww
      brightnessctl
      playerctl
      jq
      networkmanager
      upower
      alsa-utils
    ];

    xdg.configFile =
      let
        scriptAttrs = builtins.listToAttrs (
          map (s: {
            name = s.path;
            value = {
              text = s.text;
              executable = true;
            };
          }) (bar.scripts or [ ])
        );
      in
      scriptAttrs
      // {
        "eww/eww.yuck".text = bar.yuck;
        "eww/eww.scss".text = bar.scss;
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
