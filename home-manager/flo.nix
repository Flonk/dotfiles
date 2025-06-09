{ lib, pkgs, self, ... }:
{
  imports = [
    ./modules/hyprland/hyprland.nix
    ./modules/waybar/waybar.nix
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

  programs.zsh.shellAliases = {
  	update = "sudo nixos-rebuild --flake .#schnitzelwirt switch && home-manager switch --flake .#flo";
  };
  
  nixpkgs.config.allowUnfree = true;

  programs.wofi.enable = true;  
  programs.waybar.enable = true;
  
  programs.vscode.enable = true;

  programs.alacritty = {
  	enable = true; 
  	settings = {
  	  font.size = 9;
  	};
  };
 
  
  
}
