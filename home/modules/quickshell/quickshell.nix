{
  pkgs,
  config,
  lib,
  ...
}:
let
  cavaPlugin = pkgs.callPackage ./cava-plugin.nix { };
  wrappedQuickshell = pkgs.writeShellScriptBin "quickshell" ''
    export QML2_IMPORT_PATH="${cavaPlugin}/lib/qt-6/qml:$QML2_IMPORT_PATH"
    exec ${pkgs.quickshell}/bin/quickshell "$@"
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
