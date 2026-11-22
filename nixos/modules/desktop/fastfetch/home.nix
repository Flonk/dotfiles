{
  pkgs,
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.t3os.module.desktop.fastfetch.enable {
    programs.fastfetch = {
      enable = true;
      settings = {
        display.color = {
          keys = lib.mkDefault "blue";
          title = lib.mkDefault "blue";
        };
        logo = {
          source = builtins.toString config.t3os.module.desktop.stylix.lockscreenImage;
          padding = {
            top = 10;
            right = 3;
            left = 2;
          };
        };
        modules = [
          "break"
          {
            type = "title";
            key = "whoami";
          }
          "break"
          {
            type = "os";
            key = "OS";
          }
          {
            type = "host";
            key = "Host";
          }
          {
            type = "kernel";
            key = "Kernel";
          }
          "break"
          {
            type = "cpu";
            key = "";
            showPeCoreCount = true;
          }
          {
            type = "gpu";
            key = "";
          }
          {
            type = "memory";
            key = "";
          }
          "break"
          {
            type = "vulkan";
            key = "";
          }
          {
            type = "packages";
            key = "";
          }
          "break"
          {
            type = "wm";
            key = "DE";
          }
          {
            type = "lm";
            key = "";
          }
          {
            type = "terminal";
            key = "";
          }
          {
            type = "shell";
            key = "";
          }
          "break"
          {
            type = "theme";
            key = "GTK";
          }
          {
            type = "cursor";
            key = "";
          }
          {
            type = "icons";
            key = "";
          }
          {
            type = "font";
            key = "";
          }
          "break"
          {
            type = "command";
            key = "OS Age";
            text = "birth_install=$(stat -c %W /); current=$(date +%s); time_progression=$((current - birth_install)); days_difference=$((time_progression / 86400)); echo $days_difference days";
          }
          {
            type = "uptime";
            key = "Uptime";
          }
        ];
      };
    };
  };
}
