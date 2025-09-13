{
  pkgs,
  config,
  lib,
  ...
}:
{

  programs.fastfetch = {
    enable = true;
    settings = {
      logo = {
        source = builtins.toString config.theme.lockscreenImage;
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
          keyColor = "blue";
        }
        "break"
        {
          type = "os";
          key = "OS";
          keyColor = "blue";
        }
        {
          type = "host";
          key = "Host";
          keyColor = "blue";
        }
        {
          type = "kernel";
          key = "Kernel";
          keyColor = "blue";
        }
        "break"
        {
          type = "cpu";
          key = "";
          showPeCoreCount = true;
          keyColor = "blue";
        }
        {
          type = "gpu";
          key = "";
          keyColor = "blue";
        }
        {
          type = "memory";
          key = "";
          keyColor = "blue";
        }
        "break"
        {
          type = "vulkan";
          key = "";
          keyColor = "blue";
        }
        {
          type = "packages";
          key = "";
          keyColor = "blue";
        }
        "break"
        {
          type = "wm";
          key = "DE";
          keyColor = "blue";
        }
        {
          type = "lm";
          key = "";
          keyColor = "blue";
        }
        {
          type = "terminal";
          key = "";
          keyColor = "blue";
        }
        {
          type = "shell";
          key = "";
          keyColor = "blue";
        }
        "break"
        {
          type = "theme";
          key = "GTK";
          keyColor = "blue";
        }
        {
          type = "cursor";
          key = "";
          keyColor = "blue";
        }
        {
          type = "icons";
          key = "";
          keyColor = "blue";
        }
        {
          type = "font";
          key = "";
          keyColor = "blue";
        }
        "break"
        {
          type = "command";
          key = "OS Age";
          keyColor = "blue";
          text = "birth_install=$(stat -c %W /); current=$(date +%s); time_progression=$((current - birth_install)); days_difference=$((time_progression / 86400)); echo $days_difference days";
        }
        {
          type = "uptime";
          key = "Uptime";
          keyColor = "blue";
        }
      ];
    };
  };

}
