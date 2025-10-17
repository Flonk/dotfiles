{
  pkgs,
  config,
  lib,
  ...
}:
let
  barHeight = 30;

  quickmilkPlugin = pkgs.callPackage ./quickmilk-plugin.nix { };
  cavaPlugin = pkgs.callPackage ./cava-plugin.nix { };
  shaderPlugin = pkgs.callPackage ./shader-plugin.nix { };

  wrappedQuickshell = pkgs.writeShellScriptBin "quickshell" ''
    export QML2_IMPORT_PATH="${quickmilkPlugin}/lib/qt-6/qml:${cavaPlugin}/lib/qt-6/qml:${shaderPlugin}/lib/qt-6/qml:$QML2_IMPORT_PATH"
      exec ${pkgs.quickshell}/bin/quickshell "$@"
  '';

  wrappedQuickshellDev = pkgs.writeShellScriptBin "quickshell-dev" ''
        set -euo pipefail

        CONFIG_DIR="''${HOME}/quickshell-impure"             # your editable copy
        SOURCE_CONFIG="''${HOME}/.config/quickshell"         # managed by nix
        DOTFILES_DIR="''${HOME}/dotfiles/home/modules/quickshell/components"
        QS_BIN='${pkgs.quickshell}/bin/quickshell'           # Quickshell binary
    export QML2_IMPORT_PATH='${quickmilkPlugin}/lib/qt-6/qml:${cavaPlugin}/lib/qt-6/qml:${shaderPlugin}/lib/qt-6/qml:'"''${QML2_IMPORT_PATH-}"

        # Force copy from ~/.config/quickshell to ~/quickshell-impure and initialize git
        echo "[quickshell-dev] Setting up ''${CONFIG_DIR} from ''${SOURCE_CONFIG}"
        if [ -d "''${CONFIG_DIR}" ]; then
          chmod -R u+w "''${CONFIG_DIR}" 2>/dev/null || true
          rm -rf "''${CONFIG_DIR}"
        fi
        mkdir -p "''${CONFIG_DIR}"
        cp -aL "''${SOURCE_CONFIG}/." "''${CONFIG_DIR}/"
        chmod -R u+w "''${CONFIG_DIR}"

        # Initialize git repository if not already initialized
        cd "''${CONFIG_DIR}"
        if [ ! -d .git ]; then
          echo "[quickshell-dev] Initializing git repository in ''${CONFIG_DIR}"
          ${pkgs.git}/bin/git init
          ${pkgs.git}/bin/git add .
          ${pkgs.git}/bin/git commit -m "Initial commit from nix-managed config" || true
        else
          echo "[quickshell-dev] Git repository already exists, committing current state"
          ${pkgs.git}/bin/git add .
          ${pkgs.git}/bin/git commit -m "Updated from nix-managed config" || true
        fi

        if [ ! -f "''${CONFIG_DIR}/shell.qml" ]; then
          echo "No shell.qml in ''${CONFIG_DIR}" >&2
          exit 1
        fi

        RUNDIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/quickshell-dev"
        mkdir -p "''${RUNDIR}"
        PIDFILE="''${RUNDIR}/pid"

        start_qs() {
          if [ -f "''${PIDFILE}" ] && kill -0 "$(cat "''${PIDFILE}")" 2>/dev/null; then
            kill "$(cat "''${PIDFILE}")" || true
            sleep 0.05
          fi
          echo "[quickshell-dev] launching with --path ''${CONFIG_DIR}"
          "''${QS_BIN}" --path "''${CONFIG_DIR}" "''$@" &
          echo $! > "''${PIDFILE}"
        }

        cleanup() {
          [ -f "''${PIDFILE}" ] && kill "$(cat "''${PIDFILE}")" 2>/dev/null || true
          rm -f "''${PIDFILE}"
        }
        trap cleanup EXIT INT TERM

        # one-shot mode
        if [ "''${1-}" = "--no-watch" ]; then
          shift || true
          exec "''${QS_BIN}" --path "''${CONFIG_DIR}" "''$@"
        fi

        # initial start
        start_qs "''$@"

        # watch and restart on edits, syncing back to dotfiles
        export CONFIG_DIR QS_BIN PIDFILE DOTFILES_DIR
        nix run nixpkgs#watchexec -- \
          -r \
          -w "''${CONFIG_DIR}" \
          --ignore '**/.git/*' --ignore '**/*.swp' --ignore '**/*~' \
          -e qml,js,ts,css,json,yaml,yml \
          -- bash -c '
            echo "[quickshell-dev] Change detected, syncing to $DOTFILES_DIR"
            
            # Sync changes back to dotfiles (excluding .git directory)
            mkdir -p "$DOTFILES_DIR"
            ${pkgs.rsync}/bin/rsync -av --delete \
              --exclude=".git" \
              --exclude="*.swp" \
              --exclude="*~" \
              "$CONFIG_DIR/" "$DOTFILES_DIR/"
            
            # Restart quickshell
            if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
              kill "$(cat "$PIDFILE")" || true
              sleep 0.05
            fi
            echo "[quickshell-dev] reload -> --path $CONFIG_DIR"
            "$QS_BIN" --path "$CONFIG_DIR" &
            echo $! > "$PIDFILE"
          '
  '';

  # Build a transient components directory that contains the repository components
  # plus a generated Theme.qml. This directory is placed in the Nix store and
  # then used as the xdg.configFile source.
  # Extract wm and app colors from theme
  wmColors = lib.filterAttrs (n: v: lib.hasPrefix "wm" n) config.theme.color;
  appColors = lib.filterAttrs (n: v: lib.hasPrefix "app" n) config.theme.color;
  otherColors = lib.filterAttrs (
    n: v: !(lib.hasPrefix "wm" n || lib.hasPrefix "app" n)
  ) config.theme.color;

  # Helper to convert font sizes to QML properties
  fontSizesToQml = lib.concatStringsSep "\n    " (
    lib.mapAttrsToList (
      name: size:
      "readonly property int fontSize${
        lib.toUpper (lib.substring 0 1 name)
      }${lib.substring 1 (-1) name}: ${toString size}"
    ) config.theme.fontSize
  );

  # Helper to convert font families to QML properties
  fontFamiliesToQml = lib.concatStringsSep "\n    " (
    lib.mapAttrsToList (
      name: family:
      "readonly property string fontFamily${
        lib.toUpper (lib.substring 0 1 name)
      }${lib.substring 1 (-1) name}: \"${family}\""
    ) config.theme.fontFamily
  );

  # Convert colors to QML properties
  colorsToQml = lib.concatStringsSep "\n    " (
    lib.mapAttrsToList (
      name: color: "readonly property string ${name}: \"${color}\""
    ) config.theme.color
  );

  themeQml = ''
    pragma Singleton
    import QtQuick

    QtObject {
        // Bar Settings
        readonly property int barHeight: ${toString barHeight}

        // Colors
        ${colorsToQml}

        // Font Sizes
        ${fontSizesToQml}

        // Font Families
        ${fontFamiliesToQml}
    }
  '';

  componentsOut = pkgs.runCommand "quickshell-components" { inherit (pkgs) stdenv; } ''
        mkdir -p "$out"
        cp -r "${./components}/"* "$out/" || true
        cat > "$out/Theme.qml" <<'EOF'
    ${themeQml}
    EOF
  '';

  qsEnvFile = "/run/user/%U/quickshell.env";
  qsEnvPath = "/run/user/%U/quickshell.env";

  qsPowerToggle = pkgs.writeShellScript "quickshell-power-toggle" ''
    set -euo pipefail
    shopt -s nullglob

    write_qs_env() {
      local hp pid envfile
      envfile="''${QS_ENV_FILE}"

      hp="$(pidof hyprland || true)"
      if [ -z "''${hp}" ]; then
        hp="$(pidof Hyprland || true)"
      fi
      if [ -n "''${hp}" ]; then
        pid="''${hp%% *}"
        tr '\0' '\n' < "/proc/''${pid}/environ" | grep -E '^(WAYLAND_DISPLAY|XDG_RUNTIME_DIR|DBUS_SESSION_BUS_ADDRESS|HYPRLAND_INSTANCE_SIGNATURE|DISPLAY)=' \
          > "''${envfile}.tmp" || true
        if [ -s "''${envfile}.tmp" ]; then
          mv "''${envfile}.tmp" "''${envfile}"
          chmod 0600 "''${envfile}"
          echo "[qs-toggle] wrote env from Hyprland pid=''${pid} → ''${envfile}"
          return 0
        fi
      fi
      echo "[qs-toggle] could not capture Hyprland env; keeping existing env file if any"
      return 1
    }

    ac_sysfs() {
      for d in /sys/class/power_supply/*; do
        [ -f "''${d}/type" ] || continue
        t="$(cat "''${d}/type")"
        case "''${t}" in
          Mains|AC|USB|USB_C|USB-PD|USB_PD|USB-C)
            if [ -f "''${d}/online" ] && [ "$(cat "''${d}/online")" = "1" ]; then
              return 0
            fi
          ;;
        esac
      done
      return 1
    }

    ac_upower() {
      if command -v upower >/dev/null 2>&1; then
        dev="$(upower -e 2>/dev/null | grep -m1 DisplayDevice || true)"
        if [ -n "''${dev}" ]; then
          state="$(upower -i "''${dev}" 2>/dev/null | awk -F: '/^\s*state/ {gsub(/^[ \t]+|[ \t]+$/,"",$2); print $2; exit}')"
          case "''${state}" in
            charging|fully-charged|pending-charge) return 0 ;;
          esac
        fi
      fi
      return 1
    }

    is_on_ac() { ac_sysfs || ac_upower; }

    : "''${QS_ENV_FILE:?QS_ENV_FILE not set}"

    last=unknown

    start_qs() { write_qs_env || true; systemctl --user start quickshell.service || true; }
    stop_qs()  { systemctl --user stop quickshell.service  || true; }

    apply_once() {
      if is_on_ac; then
        if [ "''${last}" != "ac" ]; then
          echo "[qs-toggle] AC → start QuickShell"
          start_qs
          last=ac
        fi
      else
        if [ "''${last}" != "bat" ]; then
          echo "[qs-toggle] Battery → stop QuickShell"
          stop_qs
          last=bat
        fi
      fi
    }

    apply_once
    while sleep 2; do
      apply_once
    done
  '';

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
    exec ${wrappedQuickshell}/bin/quickshell
  '';
in
{

  # Use the generated components directory (componentsOut) as the xdg source.
  xdg.configFile."quickshell".source = componentsOut;

  # Add required packages for system monitoring and brightness control
  home.packages = with pkgs; [
    brightnessctl # For brightness control
    lm_sensors # For temperature monitoring
    pipewire # For audio capture
    quickmilkPlugin # Include our Quickmilk audio visualizer plugin
    cavaPlugin # Include legacy CAVA visualizer plugin
    shaderPlugin # Include our custom shader plugin
    wrappedQuickshell # Wrapped quickshell with cava plugin path
    wrappedQuickshellDev # Development script for quickshell

    inotify-tools # For inotifywait used in power toggle script
  ];

  # Systemd service for QuickShell
  systemd.user.services.quickshell = {
    Unit = {
      Description = "QuickShell Wayland compositor shell";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      # Also pass path of env file for the launcher (not required, but handy)
      Environment = [ "QS_ENV_FILE=${qsEnvPath}" ];
      ExecStart = qsLaunch;
      Restart = "on-failure";
      RestartSec = 1;
      TimeoutStopSec = 10;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # Power toggle (unchanged logic, just renamed variable)
  systemd.user.services.quickshell-power-toggle = {
    Unit = {
      Description = "Toggle QuickShell on AC/battery (sysfs+UPower, with env capture)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      Environment = [ "QS_ENV_FILE=${qsEnvPath}" ];
      ExecStart = qsPowerToggle;
      Restart = "always";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

}
