{ ... }:
{
  config.xdg.mimeApps.enable = true;

  config.t3os.whoami.user = "flo";

  config.t3os.module = {
    core = {
      direnv.enable = true;
      eventbus = {
        enable = true;
        bridges = [ "claude-hetzner" ];
        upstream = "claude-hetzner";
      };
      git.enable = true;
      bitwarden.enable = true;
      keyring.enable = true;
      sops.enable = true;
      zsh.enable = true;
    };
    desktop = {
      alacritty.enable = true;
      audio = {
        enable = true;
        defaultAudioSink = "alsa_output.pci-0000_00_1f.3-platform-sof_sdw.HiFi__Speaker__sink";
        headphoneSink = "alsa_output.pci-0000_00_1f.3-platform-sof_sdw.HiFi__Headphones__sink";
        easyeffects.enable = true;
        trustedBluetoothHeadsets = [
          {
            mac = "80:C3:BA:53:78:8B";
            description = "Sennheiser MOMENTUM TW 4";
          }
        ];
      };
      chinese.enable = true;
      csvlens.enable = true;
      fastfetch.enable = true;
      foot.enable = true;
      "google-chrome".enable = true;
      i18n.enable = true;
      mazama.enable = true;
      qutebrowser.enable = true;
      t3-desktop.enable = true;
      stylix = {
        enable = true;
        wallpaper = ../../../assets/wallpapers/abstract1.jpg;
        lockscreenImage = ../../../assets/logos/andamp-amp-blue.png;
        scheme = "ayu-dark";
      };
      vicinae.enable = true;
      askpass.enable = true;
      "vicinae-bitwarden".enable = true;
    };
    ai = {
      "claude-code" = {
        enable = true;
        service.enable = true;
      };
      "copilot-cli".enable = true;
      pi.enable = true;
    };
    development = {
      gh.enable = true;
      lean.enable = true;
      obsidian = {
        enable = true;
        ui.enable = true;
      };
      vscode.enable = true;
      "zed-editor".enable = true;
    };
    leisure = {
      twitch = {
        enable = true;
        clientId = "gic9a4s3nclt4smisv60y0q2biw28u";
      };
      minecraft.enable = true;
      lutris.enable = true;
      "obs-studio".enable = true;
      artcraft = {
        photocraft.enable = true;
        filmcraft.enable = true;
        vectorcraft.enable = true;
      };
      spotify.enable = true;
    };
    os = {
      "network-scripts".enable = true;
    };
    projects = {
      andamp = {
        enable = true;
        CEFKM = true;
        CEIFRS = true;
        vpn3itPriority = true;
      };
    };
  };
}
