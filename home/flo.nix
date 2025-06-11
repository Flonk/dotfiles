{ config, lib, pkgs, self, ... }:
{
  imports = [
    ./modules/hyprland/hyprland.nix
    ./modules/hyprpaper/hyprpaper.nix
    ./modules/waybar/waybar.nix
    ./modules/alacritty/alacritty.nix
    ./modules/rofi/rofi.nix
    ./modules/zsh/zsh.nix
  ];

  home = {
    packages = with pkgs; [
      nautilus
      hyprpaper
      hyprshot

      brightnessctl
      playerctl
      networkmanagerapplet
      pavucontrol

      wl-clipboard
      tree
      figlet

      google-chrome
    ];

    file.".config/wallpapers".source = ../assets/wallpapers;
    
    username = "flo";
    homeDirectory = "/home/flo";

    stateVersion = "25.05";
  };

  nixpkgs.config.allowUnfree = true;

  programs.eza.enable = true;
  programs.bat.enable = true;
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.vscode.enable = true;

  
}
