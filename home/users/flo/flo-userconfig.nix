{ ... }:
{
  config.skynet.mimeapps = true;

  config.skynet.discordId = "140292365435797504";

  config.skynet.module.home = {
    alacritty = true;
    csvlens = true;
    direnv = true;
    fastfetch = true;
    foot = true;
    git = true;
    google-chrome = true;
    hyprland = true;
    jiratui = true;
    mako = true;
    minecraft = true;
    nchat = true;
    obsidian = true;
    openclaw = true;
    quickshell = true;
    antigravity = true;
    spotify = true;
    vscode = true;
    walker = true;
    waybar = true;
    zsh = true;
  };

  config.skynet.module.home.peripherals = {
    enabled = true;
    trustedDevices = [
      {
        mac = "80:C3:BA:53:78:8B";
        description = "Sennheiser MOMENTUM TW 4";
      }
    ];
  };

  config.skynet.module.work.andamp = {
    enabled = true;
    CEFKM = true;
  };
}
