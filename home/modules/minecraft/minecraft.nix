{
  pkgs,
  config,
  lib,
  ...
}:
{

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

}
