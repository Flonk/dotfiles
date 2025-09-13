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
    ../home/modules/hyprland/hyprland.nix
    ../home/modules/hyprland/hyprpaper.nix
    ../home/modules/hyprland/hyprlock.nix
    ../home/modules/hyprland/hyprcursor.nix
    ../home/modules/google-chrome/google-chrome.nix
    ../home/modules/git/git.nix
    ../home/modules/direnv/direnv.nix
    ../home/modules/waybar/waybar.nix
    ../home/modules/mako/mako.nix
    ../home/modules/alacritty/alacritty.nix
    ../home/modules/rofi/rofi.nix
    ../home/modules/zsh/zsh.nix
    ../home/modules/vscode/vscode.nix
    ../home/modules/fastfetch/fastfetch.nix
    ../home/modules/obs-studio/obs-studio.nix
    ../home/modules/csvlens/csvlens.nix
    ../home/modules/walker/walker.nix

    # inputs.gauntlet.homeManagerModules.default
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

      code-cursor

      (pkgs.nerdfonts.override {
        fonts = [
          "FiraCode"
          "DroidSansMono"
        ];
      })
    ];

    username = "flo";
    homeDirectory = "/home/flo";

    stateVersion = "25.05";
  };

  nixpkgs.config.allowUnfree = true;
  fonts.fontconfig.enable = true;

  programs.bash.bashrcExtra = ''
    [[ $- == *i* ]] && shopt -s xpg_echo
  '';

  programs.eza.enable = true;
  programs.bat.enable = true;
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.distrobox.enable = true;

  # programs.gauntlet = {
  #  enable = true;
  #  service.enable = true;
  #};

  xdg = {
    mimeApps = {
      enable = true;
      defaultApplications = lib.mkMerge [
        (import ../home/modules/google-chrome/mimeApps.nix)
        (import ../home/modules/csvlens/mimeApps.nix)
      ];
    };
  };

}
