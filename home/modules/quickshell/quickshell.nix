{
  pkgs,
  config,
  lib,
  ...
}:
let
  cavaPlugin = pkgs.callPackage ./cava-plugin.nix { };
  barHeight = 30; # Configurable bar height
  wrappedQuickshell = pkgs.writeShellScriptBin "quickshell" ''
    export QML2_IMPORT_PATH="${cavaPlugin}/lib/qt-6/qml:$QML2_IMPORT_PATH"
    exec ${pkgs.quickshell}/bin/quickshell "$@"
  '';

  wrappedQuickshellDev = pkgs.writeShellScriptBin "quickshell-dev" ''
    set -euo pipefail

    CONFIG_DIR="''${HOME}/quickshell-impure"             # your editable copy
    SOURCE_CONFIG="''${HOME}/.config/quickshell"         # managed by nix
    DOTFILES_DIR="''${HOME}/dotfiles/home/modules/quickshell/components"
    QS_BIN='${pkgs.quickshell}/bin/quickshell'           # Quickshell binary
    export QML2_IMPORT_PATH='${cavaPlugin}/lib/qt-6/qml:'"''${QML2_IMPORT_PATH-}"

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
in
{

  # Don't use programs.quickshell to avoid conflicts with our wrapper
  # programs.quickshell = {
  #   enable = true;
  # };

  # Use the generated components directory (componentsOut) as the xdg source.
  xdg.configFile."quickshell".source = componentsOut;

  # Add required packages for system monitoring and brightness control
  home.packages = with pkgs; [
    brightnessctl # For brightness control
    lm_sensors # For temperature monitoring
    pipewire # For audio capture
    cavaPlugin # Include our custom cava plugin
    wrappedQuickshell # Wrapped quickshell with cava plugin path
    wrappedQuickshellDev # Development script for quickshell
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
      ExecStart = "${pkgs.quickshell}/bin/quickshell";
      Restart = "on-failure";
      RestartSec = 1;
      TimeoutStopSec = 10;
    };
  };

}
