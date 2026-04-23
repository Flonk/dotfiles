{
  pkgs,
  config,
  lib,
  inputs,
  ...
}:
let
  quickshellConfigDir = "${inputs."skynetshell-src".outPath}/shell";

  themeJson =
    let
      c = config.lib.stylix.colors.withHashtag;
      sz = config.stylix.fonts.sizes.terminal;
      ui = config.stylix.fonts.sansSerif.name;
      mono = config.stylix.fonts.monospace.name;
      accent = config.skynet.module.desktop.stylix.accent;
    in
    builtins.toJSON {
      fontSize = sz;
      app100 = c.base00;
      app150 = c.base01;
      app200 = c.base02;
      app600 = c.base05;
      app700 = c.base03;
      app800 = c.base06;
      app900 = c.base07;
      wm800 = accent;
      error400 = c.base08;
      error600 = c.base09;
      success600 = c.base0B;
      fontFamily = mono;
    };

  qsLaunch = pkgs.writeShellScript "quickshell-launch" ''
    set -euo pipefail

    # Decide env file path without nested ${"..:-.."} expansions (Nix-safe).
    if [ -n "''${QS_ENV_FILE:-}" ]; then
      ENV_FILE="''${QS_ENV_FILE}"
    else
      if [ -z "''${XDG_RUNTIME_DIR:-}" ]; then
        export XDG_RUNTIME_DIR="/run/user/$(id -u)"
      fi
      ENV_FILE="''${XDG_RUNTIME_DIR}/quickshell.env"
    fi

    if [ -r "''${ENV_FILE}" ]; then
      # shellcheck disable=SC2046
      export $(grep -E '^(WAYLAND_DISPLAY|XDG_RUNTIME_DIR|DBUS_SESSION_BUS_ADDRESS|HYPRLAND_INSTANCE_SIGNATURE|DISPLAY)=' "''${ENV_FILE}")
      echo "[qs-launch] sourced env from ''${ENV_FILE}"
    else
      echo "[qs-launch] env file not found: ''${ENV_FILE}" >&2
    fi

    : "''${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR missing}"
    : "''${WAYLAND_DISPLAY:?WAYLAND_DISPLAY missing}"

    SOCK="''${XDG_RUNTIME_DIR}/''${WAYLAND_DISPLAY}"
    if [ ! -S "''${SOCK}" ]; then
      echo "[qs-launch] Wayland socket missing: ''${SOCK}" >&2
      exit 200
    fi

    echo "[qs-launch] launching quickshell (WAYLAND_DISPLAY=''${WAYLAND_DISPLAY})"
    exec ${pkgs.quickshell}/bin/quickshell
  '';
in
{
  config = lib.mkIf config.skynet.module.desktop.quickshell.enable {
    xdg.configFile."quickshell".source = quickshellConfigDir;
    xdg.configFile."quickshell-theme.json".text = themeJson;

    home.packages = with pkgs; [
      brightnessctl
      lm_sensors
      pipewire
      quickshell
      inotify-tools
    ];

    systemd.user.services.quickshell = {
      Unit = {
        Description = "QuickShell Wayland compositor shell";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        Type = "simple";
        Environment = [ "QS_ENV_FILE=/run/user/%U/quickshell.env" ];
        ExecStart = qsLaunch;
        Restart = "on-failure";
        RestartSec = 1;
        TimeoutStopSec = 10;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
