{ ... }:
{
  config.skynet.wallpaper = ../../../assets/wallpapers/wallhaven-o5qwl7.jpg;
  config.skynet.mimeapps = true;

  config.skynet.module = {
    alacritty.enable = true;
    csvlens.enable = true;
    direnv.enable = true;
    fastfetch.enable = true;
    foot.enable = true;
    git.enable = true;
    google-chrome.enable = true;
    hyprland.enable = true;
    jiratui.enable = true;
    mako.enable = true;
    minecraft.enable = true;
    nchat.enable = true;
    obsidian.enable = true;
    quickshell.enable = true;
    sops.enable = true;
    spotify.enable = true;
    vicinae.enable = true;
    vscode.enable = true;
    waybar.enable = true;
    zsh.enable = true;

    peripherals = {
      enable = true;
      trustedDevices = [
        {
          mac = "80:C3:BA:53:78:8B";
          description = "Sennheiser MOMENTUM TW 4";
        }
      ];
    };

    andamp = {
      enable = true;
      CEFKM = true;
    };
  };
}
