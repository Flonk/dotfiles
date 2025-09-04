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
    ./modules/google-chrome/google-chrome.nix
    ./modules/git/git.nix
    ./modules/direnv/direnv.nix
    ./modules/waybar/waybar.nix
    ./modules/mako/mako.nix
    ./modules/alacritty/alacritty.nix
    ./modules/rofi/rofi.nix
    ./modules/zsh/zsh.nix
    ./modules/vscode/vscode.nix
    ./modules/fastfetch/fastfetch.nix
    ./modules/obs-studio/obs-studio.nix
    ./modules/csvlens/csvlens.nix

    # inputs.gauntlet.homeManagerModules.default
    inputs.walker.homeManagerModules.default
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

  programs.walker = {
    enable = true;
    runAsService = true;

    # All options from the config.json can be used here.
    config = {
      search.placeholder = "Example";
      ui.fullscreen = true;
      list = {
        height = 200;
      };
      websearch.prefix = "?";
      switcher.prefix = "/";
    };

  };

  home.activation.walkerTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    cat > "${config.xdg.configHome}/walker/themes/default.css" <<'CSS'
    .box-wrapper {
      border-radius: 0px;
      border: 4px solid ${theme.color.accent};
      background-color: ${theme.color.background};
    }
    CSS
  '';

  xdg = {
    mimeApps = {
      enable = true;
      defaultApplications = lib.mkMerge [
        (import ./modules/google-chrome/mimeApps.nix)
        (import ./modules/csvlens/mimeApps.nix)
      ];
    };
  };

}
