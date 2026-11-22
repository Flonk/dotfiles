{
  config,
  lib,
  ...
}:
{
  imports = [
    ./t3-desktop-options.nix
    ./stylix.nix
    ./src/hyprland/home.nix
    ./src/i18n/home.nix
    ./src/fastfetch/home.nix
    ./src/foot/home.nix
    ./src/mako/home.nix
    ./src/qutebrowser/home.nix
    ./src/quickshell/home.nix
    ./src/starship/home.nix
    ./src/vicinae/home.nix
  ];

  config = lib.mkIf config.t3os.module.desktop.t3-desktop.enable {
    programs.t3-desktop.quickshell.enable = true;
    programs.t3-desktop.hyprland.enable = true;
  };
}
