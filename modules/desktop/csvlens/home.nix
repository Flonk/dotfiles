{
  pkgs,
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.skynet.module.desktop.csvlens.enable {
    home.packages = with pkgs; [
      csvlens
      xlsx2csv
    ];

    xdg.mimeApps.defaultApplications = {
      "text/csv" = "csvlens.desktop";
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" = "xlsx2csv.desktop";
    };

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
  };
}
