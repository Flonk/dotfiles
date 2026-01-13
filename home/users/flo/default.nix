{
  config,
  lib,
  pkgs,
  self,
  theme,
  inputs,
  ...
}:
{
  imports = [
    ./flo-userconfig.nix
    ../common.nix
  ];

  home = {
    packages = with pkgs; [
      nixfmt-rfc-style

      nautilus
      hyprpaper
      hyprshot
      tesseract

      brightnessctl
      playerctl
      networkmanagerapplet
      pavucontrol
      libnotify
      blueman
      nwg-look
      wl-clipboard
      bluetui

      tree
      figlet
      toilet
      cowsay
      fortune
      btop
      chafa
      cool-retro-term

      postman
      jq

      musescore
      spotify
      discord
      vlc
      networkmanager

      jetbrains.idea-ultimate
      pkgs.nerd-fonts.dejavu-sans-mono
      (pkgs.stdenvNoCC.mkDerivation {
        pname = "teko";
        version = "1.0";
        src = ../../../assets/fonts/teko;
        installPhase = ''
          mkdir -p $out/share/fonts/truetype
          cp *.ttf $out/share/fonts/truetype/
        '';
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

  gtk = {
    enable = true;
  };

  xdg = {
    mimeApps = {
      enable = true;
      defaultApplications = lib.mkMerge [
        (import ../../modules/google-chrome/mimeApps.nix)
        (import ../../modules/google-chrome/file-viewer-mimeApps.nix)
        (import ../../modules/csvlens/mimeApps.nix)
      ];
    };
  };

}
