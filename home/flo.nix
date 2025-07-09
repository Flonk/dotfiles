{
  config,
  lib,
  pkgs,
  self,
  theme,
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
    ./modules/fastfetch/fastfetch.nix
    ./modules/google-chrome/google-chrome.nix
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

      tree
      figlet
      toilet
      cowsay
      fortune
      btop
      chafa

      postman
      jq

      musescore
      spotify
      discord
      obsidian
      vlc
    ];

    username = "flo";
    homeDirectory = "/home/flo";

    stateVersion = "25.05";
  };

  nixpkgs.config.allowUnfree = true;
  fonts.fontconfig.enable = true;

  programs.eza.enable = true;
  programs.bat.enable = true;
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.distrobox.enable = true;
  programs.obs-studio = {
    enable = true;

    # optional Nvidia hardware acceleration
    package = (
      pkgs.obs-studio.override {
        cudaSupport = true;
      }
    );

    plugins = with pkgs.obs-studio-plugins; [
      wlrobs
      obs-backgroundremoval
      obs-pipewire-audio-capture
      obs-gstreamer
      obs-vkcapture
    ];
  };

  systemd.user.services.force-a2dp = {
    Unit = {
      Description = "Force A2DP profile on Bluetooth headset";
      After = [ "pipewire.service" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = [ "pactl set-card-profile bluez_card.80_C3_BA_53_78_8B a2dp_sink" ];
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

}
