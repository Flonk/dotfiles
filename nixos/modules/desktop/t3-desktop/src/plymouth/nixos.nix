{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.t3-desktop.plymouth;
  t = config.programs.t3-desktop.theme;
  res = config.programs.t3-desktop.grub.resolution;
  t3Pkgs = import ../../packages.nix {
    inherit pkgs;
    accent = if t != null then t.accent else "#1d9eb6";
    frameWidth = res.width;
    frameHeight = res.height;
  };
in
{
  config = lib.mkIf cfg.enable {
    stylix.targets.plymouth.enable = false;

    boot.plymouth = {
      enable = true;
      theme = "t3-desktop";
      themePackages = [ t3Pkgs.plymouthTheme ];
    };

    boot.consoleLogLevel = 3;
    boot.kernelParams = [
      "quiet"
      "splash"
      "udev.log_level=3"
      "rd.udev.log_level=3"
      "systemd.show_status=auto"
    ];
  };
}
