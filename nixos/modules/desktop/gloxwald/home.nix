{
  config,
  lib,
  ...
}:
{
  imports = [
    ./gloxwald-options.nix
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

  config = lib.mkIf config.skynet.module.desktop.gloxwald.enable {
    programs.gloxwald.quickshell.enable = true;
    programs.gloxwald.hyprland.enable = true;
  };
}
