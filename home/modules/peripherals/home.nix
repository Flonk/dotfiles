{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.skynet.module.peripherals;

  trustScript = pkgs.writeShellScript "bluetooth-trust-peripherals" (
    lib.concatMapStrings (p: ''
      echo "Trusting ${p.description} (${p.mac})"
      ${pkgs.bluez}/bin/bluetoothctl trust ${p.mac} || true
    '') cfg.trustedDevices
  );
in
lib.mkIf (cfg.enable && cfg.trustedDevices != [ ]) {
  systemd.user.services.bluetooth-trust-peripherals = {
    Unit = {
      Description = "Auto-trust configured Bluetooth peripherals";
      # Wait until the graphical session is ready so dbus/bluetoothd are up
      After = [ "graphical-session-pre.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      # Give bluetoothd a moment to finish initialising before we poke it
      ExecStartPre = "${pkgs.coreutils}/bin/sleep 3";
      ExecStart = "${trustScript}";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
