{ config, lib, pkgs, self, inputs, ... }:
let
  gauntletPkg = inputs.self.packages.x86_64-linux.myGauntletDeps;
in {
  imports = [
    ./modules/hyprland/hyprland.nix
    ./modules/hyprland/hyprpaper.nix
    ./modules/hyprland/hyprlock.nix
    ./modules/hyprland/hyprcursor.nix
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
      nwg-look
      wl-clipboard

      tree
      figlet
      toilet
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
      hide_env_diff = true;
      log_format = "-";
      warn_timeout = "10s";
      whitelist = {
        prefix = [
          "~/repos"
        ];
      };
    };
    nix-direnv.enable = true;
  };

  home.sessionVariables.DIRENV_LOG_FORMAT = "";

  home.file.".config/direnv/direnvrc".text = ''
    source_up
  '';

  programs.git = {
    enable = true;

    delta.enable = true;

    extraConfig = {
      core = {
        askPass = "";
      };

      rerere = {
        enabled = true;
      };

      push = {
        autosetupRemote = true;
      };

      fetch = {
        prune = true;
      };

      pull = {
        rebase = true;
      };

      diff = {
        algorithm = "histogram";
      };
    }; 
  };

  programs.vscode.enable = true;

}
