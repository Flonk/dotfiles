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
    ../modules/hyprland/hyprland.nix
    ../modules/hyprland/hyprpaper.nix
    ../modules/hyprland/hyprlock.nix
    ../modules/hyprland/hyprcursor.nix
    ../modules/google-chrome/google-chrome.nix
    ../modules/git/git.nix
    ../modules/direnv/direnv.nix
    ../modules/mako/mako.nix
    ../modules/alacritty/alacritty.nix
    ../modules/zsh/zsh.nix
    ../modules/vscode/vscode.nix
    ../modules/fastfetch/fastfetch.nix
    ../modules/obs-studio/obs-studio.nix
    ../modules/csvlens/csvlens.nix
    ../modules/walker/walker.nix
    ../modules/obsidian/obsidian.nix
    ../modules/nchat/nchat.nix
    ../modules/superfile/superfile.nix
    ../modules/waybar/waybar.nix
    ../modules/quickshell/quickshell.nix
    ../modules/powersaver/powersaver.nix
    ../modules/insomnia/insomnia.nix

    # inputs.gauntlet.homeManagerModules.default
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
        src = ../../assets/fonts/teko;
        installPhase = ''
          mkdir -p $out/share/fonts/truetype
          cp *.ttf $out/share/fonts/truetype/
        '';
      })

      inputs.openconnect-pulse-launcher.packages."${pkgs.system}".openconnect-pulse-launcher
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

  gtk = {
    enable = true;
  };

  xdg = {
    mimeApps = {
      enable = true;
      defaultApplications = lib.mkMerge [
        (import ../modules/google-chrome/mimeApps.nix)
        (import ../modules/google-chrome/file-viewer-mimeApps.nix)
        (import ../modules/csvlens/mimeApps.nix)
      ];
    };
  };

}
