{
  pkgs,
  config,
  lib,
  ...
}:
{
  imports = [
    ./file-viewer.nix
  ];

  config = lib.mkIf config.skynet.module.desktop."google-chrome".enable {
    home.packages = lib.mkBefore [
      pkgs.google-chrome
    ];

    xdg.mimeApps.defaultApplications = {

      # File viewer (chrome-app-tabbed)
      "image/jpeg" = [ "chrome-app-tabbed.desktop" ];
      "image/png" = [ "chrome-app-tabbed.desktop" ];
      "image/gif" = [ "chrome-app-tabbed.desktop" ];
      "image/webp" = [ "chrome-app-tabbed.desktop" ];
      "image/apng" = [ "chrome-app-tabbed.desktop" ];
      "image/avif" = [ "chrome-app-tabbed.desktop" ];
      "image/svg+xml" = [ "chrome-app-tabbed.desktop" ];
      "image/bmp" = [ "chrome-app-tabbed.desktop" ];
      "image/x-icon" = [ "chrome-app-tabbed.desktop" ];
      "audio/mpeg" = [ "chrome-app-tabbed.desktop" ];
      "audio/mp3" = [ "chrome-app-tabbed.desktop" ];
      "audio/x-ogg" = [ "chrome-app-tabbed.desktop" ];
      "audio/ogg" = [ "chrome-app-tabbed.desktop" ];
      "application/ogg" = [ "chrome-app-tabbed.desktop" ];
      "video/ogg" = [ "chrome-app-tabbed.desktop" ];
      "audio/webm" = [ "chrome-app-tabbed.desktop" ];
      "video/webm" = [ "chrome-app-tabbed.desktop" ];
      "video/mp4" = [ "chrome-app-tabbed.desktop" ];
      "audio/wav" = [ "chrome-app-tabbed.desktop" ];
      "audio/x-wav" = [ "chrome-app-tabbed.desktop" ];
      "audio/flac" = [ "chrome-app-tabbed.desktop" ];
      "application/pdf" = [ "chrome-app-tabbed.desktop" ];
    };
  };
}
