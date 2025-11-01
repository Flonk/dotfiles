{
  config,
  lib,
  pkgs,
  ...
}:

{
  home.packages = with pkgs; [
    insomnia
  ];

  xdg.desktopEntries.insomnia = {
    name = "Insomnia";
    exec = "${pkgs.insomnia}/bin/insomnia %U";
    terminal = false;
    type = "Application";
    icon = "insomnia";
    comment = "API Client and Design Tool";
    categories = [
      "Development"
      "Network"
    ];
    mimeType = [
      "x-scheme-handler/insomnia"
    ];
  };
}
