{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkIf config.skynet.module.fingerprint.enable {
    # Enable fingerprint reader daemon
    services.fprintd.enable = true;

    # Enable PAM fingerprint authentication for login and hyprlock
    security.pam.services.login.fprintAuth = true;
    security.pam.services.hyprlock.fprintAuth = true;

    # Register skynet CLI scripts
    skynet.cli.scripts = [
      {
        command = [
          "fingerprint"
          "enroll"
        ];
        description = "Interactively enroll fingerprints via fprintd";
        script = ./skynet-scripts/enroll-fingerprints.ts;
        preview = "echo 'Launches an interactive wizard to enroll one or more fingerprints using fprintd.'";
      }
    ];
  };
}
