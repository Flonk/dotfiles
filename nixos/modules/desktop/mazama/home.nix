{
  pkgs,
  config,
  lib,
  inputs,
  ...
}:
{
  config = lib.mkIf config.skynet.module.desktop.mazama.enable {
    home.packages = [ inputs.mazama.packages.${pkgs.stdenv.hostPlatform.system}.default ];

    xdg.desktopEntries.mazama = {
      name = "mazama";
      genericName = "Gopher and Gemini Client";
      exec = "foot -e mazama %u";
      terminal = false;
      categories = [ "Network" ];
      mimeType = [
        "x-scheme-handler/gopher"
        "x-scheme-handler/gemini"
      ];
    };

    xdg.mimeApps.defaultApplications = {
      "x-scheme-handler/gopher" = "mazama.desktop";
      "x-scheme-handler/gemini" = "mazama.desktop";
    };
  };
}
