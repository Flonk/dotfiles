{ config, lib, pkgs, self, ... }:
{
  imports = [
    ./modules/hyprland/hyprland.nix
    ./modules/waybar/waybar.nix
    ./modules/alacritty/alacritty.nix
    ./modules/rofi/rofi.nix
    ./modules/zsh/zsh.nix
  ];

  home = {
    packages = with pkgs; [
      hello
      nautilus
      walker
      hyprpaper
      hyprshot

      brightnessctl
      playerctl
      networkmanagerapplet
      pavucontrol

      wl-clipboard
    ];
    
    # This needs to actually be set to your username
    username = "flo";
    homeDirectory = "/home/flo";

    stateVersion = "25.05";
  };

  nixpkgs.config.allowUnfree = true;

  programs.waybar.enable = true;
  programs.vscode.enable = true;
}
