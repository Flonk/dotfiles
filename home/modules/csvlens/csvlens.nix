{
  pkgs,
  config,
  lib,
  ...
}:
{

  home.packages = with pkgs; [
    csvlens
    xlsx2csv
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

  # convert excel to csv and use csvlens to view
  xdg.desktopEntries.xlsx2csv = {
    name = "xlsx2csv";
    genericName = "XLSX Viewer";
    comment = "Convert XLSX files to CSV format";
    exec = "alacritty -e sh -c \"xlsx2csv %f | csvlens -d auto\"";
    terminal = false;
    categories = [ "Utility" ];
    mimeType = [ "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" ];
  };

}
