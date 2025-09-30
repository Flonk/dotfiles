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

  wrapper = pkgs.writeShellScriptBin "xdg-open-tabbed" ''
    set -euo pipefail
    ${pkgs.hyprland}/bin/hyprctl dispatch 'hy3:makegroup tab' || true
    open_one() {
      local arg="$1" uri
      if [ -n "$arg" ] && ! printf '%s' "$arg" | grep -q '://'; then
        uri="file://$(${pkgs.coreutils}/bin/realpath "$arg")"
      else
        uri="$arg"ch
      fi
      ${pkgs.hyprland}/bin/hyprctl dispatch 'hy3:setephemeral true' || true
      exec google-chrome-stable --app="$uri"
    }
    if [ "$#" -ge 1 ]; then
      open_one "$1"
    else
      echo "xdg-open-tabbed: nothing to open" >&2
      exit 1
    fi
  '';
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

    # inputs.gauntlet.homeManagerModules.default
  ];

  home = {
    packages = with pkgs; [
      wrapper

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

  xdg.desktopEntries.chrome-app-tabbed = {
    name = "Chrome (app, tabbed)";
    exec = "${wrapper}/bin/xdg-open-tabbed %u";
    terminal = false;
    type = "Application";
    mimeType = [
      # Images
      "image/jpeg"
      "image/png"
      "image/gif"
      "image/webp"
      "image/apng"
      "image/avif"
      "image/svg+xml"
      "image/bmp"
      "image/x-icon"

      # Audio / Video
      "audio/mpeg"
      "audio/mp3"
      "audio/ogg"
      "audio/x-ogg"
      "application/ogg"
      "video/ogg"
      "audio/webm"
      "video/webm"
      "video/mp4"
      "audio/wav"
      "audio/x-wav"
      "audio/flac"

      # Docs
      "application/pdf"
    ];
    noDisplay = true;
  };

  gtk = {
    enable = true;
  };

  xdg = {
    mimeApps = {
      enable = true;
      defaultApplications = lib.mkMerge [
        (import ../modules/google-chrome/mimeApps.nix)
        (import ../modules/csvlens/mimeApps.nix)
        {
          "image/jpeg" = [ "chrome-app-tabbed.desktop" ];
          "image/png" = [ "chrome-app-tabbed.desktop" ];
          "image/gif" = [ "chrome-app-tabbed.desktop" ];
          "image/webp" = [ "chrome-app-tabbed.desktop" ];
          "image/apng" = [ "chrome-app-tabbed.desktop" ];
          "image/avif" = [ "chrome-app-tabbed.desktop" ];
          "image/svg+xml" = [ "chrome-app-tabbed.desktop" ];
          "image/bmp" = [ "chrome-app-tabbed.desktop" ];
          "image/x-icon" = [ "chrome-app-tabbed.desktop" ];

          "audio/mpeg" = [ "chrome-app-tabbed.desktop" ];
          "audio/mp3" = [ "chrome-app-tabbed.desktop" ];
          "audio/x-ogg" = [ "chrome-app-tabbed.desktop" ];
          "audio/ogg" = [ "chrome-app-tabbed.desktop" ];
          "application/ogg" = [ "chrome-app-tabbed.desktop" ];
          "video/ogg" = [ "chrome-app-tabbed.desktop" ];
          "audio/webm" = [ "chrome-app-tabbed.desktop" ];
          "video/webm" = [ "chrome-app-tabbed.desktop" ];
          "video/mp4" = [ "chrome-app-tabbed.desktop" ];
          "audio/wav" = [ "chrome-app-tabbed.desktop" ];
          "audio/x-wav" = [ "chrome-app-tabbed.desktop" ];
          "audio/flac" = [ "chrome-app-tabbed.desktop" ];

          "application/pdf" = [ "chrome-app-tabbed.desktop" ];
        }
      ];
    };
  };

  # Removed inline Eww config; moved to ../modules/eww/eww.nix
  # xdg.configFile."eww/eww.yuck".text = '' ... '';
  # xdg.configFile."eww/eww.scss".text = '' ... '';

  # Removed Eww services here; moved to ../modules/eww/eww.nix
  # systemd.user.services.eww-daemon = { ... };
  # systemd.user.services.eww-bar = { ... };

}
