{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkIf config.skynet.module.system.fingerprint {
    # Enable fingerprint reader daemon
    services.fprintd.enable = true;

    # Enable PAM fingerprint authentication for login and hyprlock
    security.pam.services.login.fprintAuth = true;
    security.pam.services.hyprlock.fprintAuth = true;
  };
}
