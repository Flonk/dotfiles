{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.t3os.module.desktop.t3-desktop;
  s = config.lib.stylix.colors.withHashtag;
  border = config.t3os.module.desktop.stylix.accent;
  mon = config.t3os.host.primaryMonitor;
  fontFamily = config.stylix.fonts.monospace.name;
in
{
  imports = [
    ./t3-desktop-options.nix
    ./src/greeter/nixos.nix
    ./src/grub/nixos.nix
    ./src/plymouth/nixos.nix
    ./src/hyprland/nixos.nix
  ];

  config = lib.mkIf cfg.enable {
    programs.t3-desktop.hyprland.enable = true;

    programs.t3-desktop.theme = {
      bg_base = s.base00;
      bg_active = s.base01;
      accent = border;
      fg_primary = s.base05;
    };

    programs.t3-desktop.greeter = {
      enable = true;
      autologin = true;
      output = "eDP-1";
      settings = {
        exec = "start-hyprland >/dev/null 2>&1";
        user = config.t3os.host.adminUser;
      };
      font = {
        name = config.stylix.fonts.monospace.name;
        size = 20;
        package = config.stylix.fonts.monospace.package;
      };
    };

    programs.t3-desktop.plymouth.enable = true;

    programs.t3-desktop.grub = {
      enable = true;

      resolution = {
        width = mon.width;
        height = mon.height;
      };

      font = {
        family = fontFamily;
        regular = "${pkgs.dejavu_fonts}/share/fonts/truetype/DejaVuSansMono.ttf";
        bold = "${pkgs.dejavu_fonts}/share/fonts/truetype/DejaVuSansMono-Bold.ttf";
      };
    };
  };
}
