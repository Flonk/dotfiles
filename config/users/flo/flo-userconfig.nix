{ ... }:
{
  config.skynet.mimeapps = true;

  config.skynet.module = {
    assorted = {
      jiratui.enable = false;
      nchat.enable = true;
    };
    core = {
      direnv.enable = true;
      git.enable = true;
      keyring.enable = true;
      sops.enable = true;
      zsh.enable = true;
    };
    desktop = {
      alacritty.enable = true;
      csvlens.enable = true;
      fastfetch.enable = true;
      foot.enable = true;
      "google-chrome".enable = true;
      hyprland.enable = true;
      mako.enable = true;
      quickshell.enable = true;
      stylix = {
        enable = true;
        wallpaper = ../../../assets/wallpapers/wallhaven-o5qwl7.jpg;
        lockscreenImage = ../../../assets/logos/andamp-amp-blue.png;
      };
      vicinae.enable = true;
      waybar.enable = true;
    };
    development = {
      "claude-code".enable = true;
      obsidian.enable = true;
      vscode.enable = true;
      "zed-editor".enable = true;
    };
    leisure = {
      minecraft.enable = true;
      spotify.enable = true;
    };
    os = {
      peripherals = {
        enable = true;
        trustedDevices = [
          {
            mac = "80:C3:BA:53:78:8B";
            description = "Sennheiser MOMENTUM TW 4";
          }
        ];
      };
    };
    projects = {
      andamp = {
        enable = true;
        CEFKM = true;
        CEIFRS = true;
      };
      personal = {
        dwain.enable = true;
      };
    };
  };
}
