{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.programs.gloxwald.quickshell;

  quickshellSrc = builtins.path {
    path = ../quickshell;
    name = "gloxwald-quickshell";
  };

  quickshellConfigDir = "${quickshellSrc}/shell";

  themeJson =
    let
      c = config.lib.stylix.colors.withHashtag;
    in
    builtins.toJSON {
      fontSize = config.stylix.fonts.sizes.terminal;
      fontFamily = config.stylix.fonts.monospace.name;
      app100 = c.base00;
      app150 = c.base01;
      app200 = c.base02;
      app600 = c.base05;
      app700 = c.base03;
      app800 = c.base06;
      app900 = c.base07;
      wm800 = config.programs.gloxwald.stylix.accent;
      error400 = c.base08;
      error600 = c.base09;
      success600 = c.base0B;
    };

  launchScript = pkgs.writeShellScript "gloxwald-quickshell-launch" ''
    if [ -z "''${XDG_RUNTIME_DIR:-}" ]; then
      export XDG_RUNTIME_DIR="/run/user/$(id -u)"
    fi
    : "''${WAYLAND_DISPLAY:?WAYLAND_DISPLAY missing}"
    for _ in $(seq 50); do
      if [ -S "''${XDG_RUNTIME_DIR}/''${WAYLAND_DISPLAY}" ]; then
        exec ${pkgs.quickshell}/bin/quickshell
      fi
      sleep 0.2
    done
    echo "wayland socket never appeared: ''${XDG_RUNTIME_DIR}/''${WAYLAND_DISPLAY}" >&2
    exit 1
  '';

in
{
  imports = [
    ./options.nix
    ./hyprland
    ./stylix.nix
  ];

  config = mkIf cfg.enable {
    xdg.configFile."quickshell".source = quickshellConfigDir;
    xdg.configFile."quickshell-theme.json".text = themeJson;

    home.packages = with pkgs; [
      brightnessctl
      inotify-tools
      lm_sensors
      pipewire
      quickshell
    ];

    systemd.user.services.quickshell = {
      Unit = {
        Description = "gloxwald quickshell bar";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${launchScript}";
        Restart = "on-failure";
        RestartSec = 1;
        TimeoutStopSec = 10;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
