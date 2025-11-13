{
  config,
  lib,
  pkgs,
  ...
}:

let
  insomniaAppImage = pkgs.appimageTools.wrapType2 {
    pname = "insomnia";
    version = "2022.6.0";
    src = pkgs.fetchurl {
      url = "https://github.com/Kong/insomnia/releases/download/core@2022.6.0/Insomnia.Core-2022.6.0.AppImage";
      sha256 = "0zjfj5jbh65kzm6bg20zhaxkh636531d7bsqzsx4v9b0r21bk47b";
    };
  };
in
{
  home.packages = [
    insomniaAppImage
  ];

  xdg.desktopEntries.insomnia = {
    name = "Insomnia";
    exec = "${insomniaAppImage}/bin/insomnia %U";
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
