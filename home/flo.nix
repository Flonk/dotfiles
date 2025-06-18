{
  config,
  lib,
  pkgs,
  self,
  inputs,
  ...
}:
let
  gauntletPkg = inputs.self.packages.x86_64-linux.myGauntletDeps;
in
{
  imports = [
    ./modules/hyprland/hyprland.nix
    ./modules/hyprland/hyprpaper.nix
    ./modules/hyprland/hyprlock.nix
    ./modules/hyprland/hyprcursor.nix
    ./modules/git/git.nix
    ./modules/direnv/direnv.nix
    ./modules/waybar/waybar.nix
    ./modules/mako/mako.nix
    ./modules/alacritty/alacritty.nix
    ./modules/rofi/rofi.nix
    ./modules/zsh/zsh.nix
    ./modules/vscode/vscode.nix
  ];

  home = {
    packages = with pkgs; [
      nixfmt-rfc-style

      nautilus
      hyprpaper
      hyprshot

      brightnessctl
      playerctl
      networkmanagerapplet
      pavucontrol
      libnotify
      blueman
      nwg-look
      wl-clipboard

      nerd-fonts.fira-code
      nerd-fonts.fira-mono

      tree
      figlet
      toilet
      cowsay
      fortune
      btop

      postman

      google-chrome

      musescore
      spotify
      discord
      obsidian
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

  programs.distrobox.enable = true;

  programs.fastfetch = {
    enable = true;
    settings = {
      modules = [
        "break"
        {
          type = "title";
          key = "";
          keyColor = "yellow";
        }
        {
          type = "custom";
          format = "┌────────────────────────────────────────────────────┐";
        }
        {
          type = "os";
          key = "OS";
          keyColor = "yellow";
        }
        {
          type = "host";
          key = "Host";
          keyColor = "green";
        }
        {
          type = "kernel";
          key = "Kernel";
          keyColor = "yellow";
        }
        {
          type = "cpu";
          key = "│ ├";
          showPeCoreCount = true;
          keyColor = "green";
        }
        {
          type = "gpu";
          key = "│ ├󰍛";
          keyColor = "green";
        }
        {
          type = "memory";
          key = "└ └";
          keyColor = "green";
        }
        {
          type = "custom";
          format = "└────────────────────────────────────────────────────┘";
        }
        "break"
        {
          type = "custom";
          format = "┌──────────────────────Software──────────────────────┐";
        }
        {
          type = "vulkan";
          key = "│ ├";
          keyColor = "yellow";
        }
        {
          type = "packages";
          key = "└ └";
          keyColor = "yellow";
        }
        "break"
        {
          type = "wm";
          key = "󰇄 DE";
          keyColor = "blue";
        }
        {
          type = "lm";
          key = "│ ├󰍂";
          keyColor = "blue";
        }
        {
          type = "terminal";
          key = "│ ├";
          keyColor = "blue";
        }
        {
          type = "shell";
          key = "└ └";
          keyColor = "blue";
        }
        {
          type = "custom";
          format = "└────────────────────────────────────────────────────┘";
        }
        "break"
        {
          type = "custom";
          format = "┌──────────────────────Theming───────────────────────┐";
        }
        {
          type = "theme";
          key = "󰉼 GTK";
          keyColor = "cyan";
        }
        {
          type = "cursor";
          key = "│  ├󰇀";
          keyColor = "cyan";
        }
        {
          type = "icons";
          key = "│  ├";
          keyColor = "cyan";
        }
        {
          type = "font";
          key = "└  └󰗧";
          keyColor = "cyan";
        }
        {
          type = "custom";
          format = "└────────────────────────────────────────────────────┘";
        }
        "break"
        {
          type = "custom";
          format = "┌────────────────────Uptime / Age────────────────────┐";
        }
        {
          type = "command";
          key = "  OS Age ";
          keyColor = "magenta";
          text = "birth_install=$(stat -c %W /); current=$(date +%s); time_progression=$((current - birth_install)); days_difference=$((time_progression / 86400)); echo $days_difference days";
        }
        {
          type = "uptime";
          key = "  Uptime ";
          keyColor = "magenta";
        }
        {
          type = "custom";
          format = "└────────────────────────────────────────────────────┘";
        }
        "break"
      ];
    };
  };

}
