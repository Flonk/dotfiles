{
  pkgs,
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.skynet.module.core.keyring.enable {
    home.packages = with pkgs; [
      gnome-keyring
      libsecret
      gcr
    ];

    # Run gnome-keyring as a user service so apps can persist secrets (e.g. Zed OAuth tokens)
    systemd.user.services.gnome-keyring-secrets = {
      Unit = {
        Description = "GNOME Keyring secrets component";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.gnome-keyring}/bin/gnome-keyring-daemon --foreground --components=secrets --unlock";
        Restart = "on-failure";
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };

    skynet.cli.scripts = [
      {
        command = [
          "init-keyring"
        ];
        title = "Initialize GNOME Keyring";
        script = pkgs.writeShellScript "init-keyring.sh" ''
          set -euo pipefail
          echo "Creating the GNOME Keyring 'login' collection..."
          echo "You will be prompted to set a password for the keyring."
          echo "(Leave empty for auto-unlock on login.)"
          echo ""
          echo "test" | ${pkgs.libsecret}/bin/secret-tool store --label "keyring-init" keyring-init-key keyring-init-value
          echo ""
          echo "✅ Keyring initialized."
        '';
        usage = "Creates the GNOME Keyring 'login' collection so apps can persist secrets (e.g. OAuth tokens) across restarts.";
      }
    ];
  };
}
