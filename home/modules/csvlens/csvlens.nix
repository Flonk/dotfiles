{
  pkgs,
  config,
  lib,
  ...
}:
{

  home.packages = with pkgs; [
    csvlens
  ];

  xdg.desktopEntries.csvlens = {
    name = "csvlens";
    genericName = "CSV Viewer";
    comment = "Terminal CSV viewer";
    exec = "alacritty -e csvlens -d auto %f";
    terminal = false;
    categories = [ "Utility" ];
    mimeType = [ "text/csv" ];
  };

}
