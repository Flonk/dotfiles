{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.skynet.module.desktop.skynetshell;

  themeJson =
    let
      c = config.lib.stylix.colors.withHashtag;
      sz = config.stylix.fonts.sizes.terminal;
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
    fi

    : "''${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR missing}"
    : "''${WAYLAND_DISPLAY:?WAYLAND_DISPLAY missing}"

    SOCK="''${XDG_RUNTIME_DIR}/''${WAYLAND_DISPLAY}"
    if [ ! -S "''${SOCK}" ]; then
      echo "[qs-launch] Wayland socket missing: ''${SOCK}" >&2
      exit 200
    fi

    exec ${pkgs.quickshell}/bin/quickshell
  '';
in
{
  config = lib.mkIf cfg.enable {
    programs.skynetshell.quickshell.enable = true;

    xdg.configFile."quickshell-theme.json".text = themeJson;

    systemd.user.services.quickshell.Service = {
      Environment = [ "QS_ENV_FILE=/run/user/%U/quickshell.env" ];
      ExecStart = lib.mkForce qsLaunch;
    };
  };
}
