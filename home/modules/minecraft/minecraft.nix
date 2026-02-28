{
  pkgs,
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.skynet.module.minecraft.enable {
    home.packages = with pkgs; [
      prismlauncher
    ];

    xdg.desktopEntries = {
      prismlauncher = {
        name = "Prism Launcher";
        comment = "A custom launcher for Minecraft";
        exec = "prismlauncher";
        icon = "prismlauncher";
        categories = [ "Game" ];
        terminal = false;
      };
    };
  };
}
