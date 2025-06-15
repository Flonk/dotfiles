{ config, lib, pkgs, self, inputs, ... }:
let
  gauntletPkg = inputs.self.packages.x86_64-linux.myGauntletDeps;
in {
  imports = [
    ./modules/hyprland/hyprland.nix
    ./modules/hyprland/hyprpaper.nix
    ./modules/hyprland/hyprlock.nix
    ./modules/waybar/waybar.nix
    ./modules/mako/mako.nix
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
      libnotify
      blueman
      wl-clipboard

      tree
      figlet
      cowsay
      fortune

      google-chrome

      musescore
      spotify
      discord
    ];
    
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

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;

    config = {
      load_dotenv = true;
      whitelist = {
        prefix = [
          "~/repos"
        ];
      };
    };

    nix-direnv.enable = true;
  };

  programs.vscode.enable = true;

  
}
