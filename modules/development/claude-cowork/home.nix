{
  pkgs,
  config,
  lib,
  ...
}:
let
  installDir = "${config.home.homeDirectory}/.local/share/claude-desktop";

  # Establishes Electron single-instance lock BEFORE frame-fix-wrapper.js
  # spoofs process.platform to 'darwin'. This gives us the real Linux file-based
  # lock, so claude:// callback URLs from the browser get forwarded to the
  # running instance instead of being lost.
  singleInstanceScript = ./single-instance.cjs;

  launcher = pkgs.writeShellApplication {
    name = "claude-desktop";
    runtimeInputs = with pkgs; [
      electron
      dbus
      asar
      coreutils
    ];
    text = ''
      if [[ ! -d "${installDir}/linux-app-extracted" ]]; then
        echo "Claude Cowork is not installed yet."
        echo "Run: skynet claude-cowork install"
        exit 1
      fi

      # Load single-instance lock before the app spoofs process.platform.
      # This enables claude:// callback forwarding from second instances.
      export NODE_OPTIONS="--require=${singleInstanceScript}"

      exec bash "${installDir}/launch.sh" "$@"
    '';
  };
in
{
  config = lib.mkIf config.skynet.module.development."claude-cowork".enable {
    home.packages = [
      launcher
    ]
    ++ (with pkgs; [
      # Runtime deps for Claude Desktop (Electron app)
      electron
      nodejs
      # Setup deps — used by install.sh during initial setup / updates
      asar
      p7zip
      bubblewrap
      python3
      curl
      git
      xdg-utils
      # Keyring — required for safeStorage so OAuth tokens persist between sessions
      gnome-keyring
      libsecret
    ]);

    # Run gnome-keyring as a user service so safeStorage works (avoids OAuth loop)
    systemd.user.services.gnome-keyring-secrets = {
      Unit = {
        Description = "GNOME Keyring secrets component (for Claude Cowork safeStorage)";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.gnome-keyring}/bin/gnome-keyring-daemon --foreground --components=secrets";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    xdg.desktopEntries.claude-cowork = {
      name = "Claude Cowork";
      comment = "Anthropic Claude Desktop with local agent support (Linux)";
      exec = "claude-desktop %U";
      icon = "claude";
      categories = [
        "Development"
        "Utility"
      ];
      mimeType = [ "x-scheme-handler/claude" ];
    };

    skynet.cli.scripts = [
      {
        command = [
          "claude-cowork"
          "install"
        ];
        title = "Claude Cowork: Install / Update";
        script = ./skynet-scripts/install.sh;
        usage = "Download the Claude Desktop DMG and install Cowork Linux in ~/.local/share/claude-desktop. Re-run to update.";
      }
    ];
  };
}
