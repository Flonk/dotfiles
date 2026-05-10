{
  pkgs,
  ...
}:
{
  imports = [
    ./flo-userconfig.nix
    ../common.nix
  ];

  home = {
    packages = with pkgs; [
      nixfmt

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
      discord
      vlc
      networkmanager

      jetbrains.idea
      unityhub

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
      (pkgs.stdenvNoCC.mkDerivation {
        pname = "hypik";
        version = "1.0";
        src = ../../../assets/fonts/hypik;
        installPhase = ''
          mkdir -p $out/share/fonts/opentype
          cp *.otf $out/share/fonts/opentype/
        '';
      })
    ];

    username = "flo";
    homeDirectory = "/home/flo";

    stateVersion = "25.05";
  };

  nixpkgs.config.allowUnfree = true;

  # Only restart services whose unit files actually changed,
  # rather than restarting all managed services on every build.
  systemd.user.startServices = "sd-switch";

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

}
