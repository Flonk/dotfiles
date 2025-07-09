{
  pkgs,
  config,
  lib,
  theme,
  ...
}:
{

  home.packages = lib.mkBefore [
    pkgs.google-chrome
  ];

  xdg.mimeApps.defaultApplications = {
    "x-scheme-handler/http" = "google-chrome.desktop";
    "x-scheme-handler/https" = "google-chrome.desktop";
    "text/html" = "google-chrome.desktop";
  };

}
