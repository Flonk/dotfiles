{
  pkgs,
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.t3os.module.desktop.foot.enable {
    programs.foot = {
      enable = true;

      settings = {
        main = {
          login-shell = "no";
          locked-title = "no";
          letter-spacing = "0";
          dpi-aware = "no";
          initial-window-size-pixels = "700x500";
          initial-window-mode = "windowed";
          pad = "6x6";
          resize-by-cells = "yes";
          word-delimiters = ",│`|:\"'()[]{}<>";
        };

        scrollback = {
          lines = "1000";
        };
      };
    };

    xdg.desktopEntries.foot = {
      name = "Foot Terminal";
      genericName = "Terminal";
      comment = "Fast, lightweight and minimalistic Wayland terminal emulator";
      exec = "foot";
      icon = "foot";
      terminal = false;
      type = "Application";
      categories = [
        "System"
        "TerminalEmulator"
      ];
    };
  };
}
