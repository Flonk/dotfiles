{
  pkgs,
  config,
  lib,
  inputs,
  ...
}:
let
  barSize = 50;
  quickshellRepo = inputs."skynetshell-src".outPath;
  quickshellConfigDir = "${quickshellRepo}/shell";

  wrappedQuickshell = pkgs.quickshell;

  wrappedQuickshellDev = pkgs.writeShellScriptBin "quickshell-dev" ''
    set -euo pipefail

    CONFIG_DIR="''${HOME}/quickshell-impure"             # your editable copy
    SOURCE_CONFIG="''${HOME}/.config/quickshell"         # managed by nix
    REPO_DIR="''${HOME}/repos/personal/skynetshell/shell"
    QS_BIN='${pkgs.quickshell}/bin/quickshell'           # Quickshell binary

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

    # watch and restart on edits, syncing back to the source repo
    export CONFIG_DIR QS_BIN PIDFILE REPO_DIR
    nix run nixpkgs#watchexec -- \
      -r \
      -w "''${CONFIG_DIR}" \
      --ignore '**/.git/*' --ignore '**/*.swp' --ignore '**/*~' \
      -e qml,js,ts,css,json,yaml,yml \
      -- bash -c '
        echo "[quickshell-dev] Change detected, syncing to $REPO_DIR"
        
        # Sync changes back to the skynetshell repo (excluding .git directory)
        mkdir -p "$REPO_DIR"
        ${pkgs.rsync}/bin/rsync -av --delete \
          --exclude=".git" \
          --exclude="*.swp" \
          --exclude="*~" \
          "$CONFIG_DIR/" "$REPO_DIR/"
        
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

  quickshellAssets = [
    {
      name = "logoAndampAmpBlue";
      relPath = "logos/andamp-amp-blue.png";
    }
    {
      name = "logoTileGrey";
      relPath = "logos/tile-grey.png";
    }
  ];

  assetQmlProperties = lib.concatStringsSep "\n        " (
    map (
      asset: ''readonly property url ${asset.name}: Qt.resolvedUrl("assets/${asset.relPath}")''
    ) quickshellAssets
  );

  assetQmlBlock =
    if quickshellAssets == [ ] then
      ""
    else
      ''
        // Asset URLs
        ${assetQmlProperties}
      '';

  # Helper to convert font sizes to QML properties
  fontSizesToQml =
    let
      sizes = config.stylix.fonts.sizes;
      fontSizes = {
        tiny = sizes.terminal - 2;
        small = sizes.terminal - 1;
        normal = sizes.terminal;
        big = sizes.terminal + 1;
        bigger = sizes.terminal + 3;
        huge = sizes.terminal + 5;
        humongous = sizes.terminal + 11;
      };
    in
    lib.concatStringsSep "\n    " (
      lib.mapAttrsToList (
        name: size:
        "readonly property int fontSize${
          lib.toUpper (lib.substring 0 1 name)
        }${lib.substring 1 (-1) name}: ${toString size}"
      ) fontSizes
    );

  # Helper to convert font families to QML properties
  fontFamiliesToQml =
    let
      fonts = config.stylix.fonts;
      fontFamilies = {
        ui = fonts.sansSerif.name;
        uiNf = fonts.monospace.name;
        mono = fonts.monospace.name;
        monoNf = fonts.monospace.name;
      };
    in
    lib.concatStringsSep "\n    " (
      lib.mapAttrsToList (
        name: family:
        "readonly property string fontFamily${
          lib.toUpper (lib.substring 0 1 name)
        }${lib.substring 1 (-1) name}: \"${family}\""
      ) fontFamilies
    );

  # Convert colors to QML properties
  colorsToQml =
    let
      c = config.lib.stylix.colors.withHashtag;
      colorMapping = {
        app100 = c.base00;
        app150 = c.base01;
        app200 = c.base02;
        app600 = c.base05;
        app700 = c.base03;
        app800 = c.base06;
        app900 = c.base07;
        wm800 = config.skynet.module.desktop.stylix.accent;
        error400 = c.base08;
        error600 = c.base09;
        success600 = c.base0B;
      };
    in
    lib.concatStringsSep "\n    " (
      lib.mapAttrsToList (name: hex: "readonly property color ${name}: \"${hex}\"") colorMapping
    );

  themeQml = ''
        pragma Singleton
        import QtQuick

        QtObject {
            // Bar Settings
            readonly property int barSize: ${toString barSize}

            // Colors
            ${colorsToQml}

            // Font Sizes
            ${fontSizesToQml}

            // Font Families
            ${fontFamiliesToQml}

    ${assetQmlBlock}
        }
  '';

  componentsOut = pkgs.runCommand "quickshell-components" { inherit (pkgs) stdenv; } ''
        mkdir -p "$out"
        cp -r "${quickshellConfigDir}/." "$out/"
      rm -f "$out/Theme.qml"
        cat > "$out/Theme.qml" <<'EOF'
    ${themeQml}
    EOF
  '';

  qsEnvPath = "/run/user/%U/quickshell.env";

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
  config = lib.mkIf config.skynet.module.desktop.quickshell.enable {
    # Use the generated components directory (componentsOut) as the xdg source.
    xdg.configFile."quickshell".source = componentsOut;

    # Add required packages for system monitoring and brightness control
    home.packages = with pkgs; [
      brightnessctl # For brightness control
      lm_sensors # For temperature monitoring
      pipewire # For audio capture
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
  };
}
