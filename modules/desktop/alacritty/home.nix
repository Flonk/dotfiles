{
  pkgs,
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.skynet.module.desktop.alacritty.enable {
    programs.alacritty = {
      enable = true;
      settings = {
        font.size = lib.mkDefault config.stylix.fonts.sizes.terminal;
        font.normal.family = lib.mkDefault config.stylix.fonts.monospace.name;

        keyboard = {
          bindings = [
            # Ctrl+Enter → send CSI u sequence
            {
              key = "Enter";
              mods = "Control";
              chars = "\\u001b";
            }
          ];
        };
      };
    };
  };
}
