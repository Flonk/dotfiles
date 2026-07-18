{
  pkgs,
  config,
  lib,
  ...
}:
let
  wrapper = pkgs.writeShellScriptBin "xdg-open-tabbed" ''
    set -euo pipefail
    open_one() {
      local arg="$1" uri
      if [ -n "$arg" ] && ! printf '%s' "$arg" | grep -q '://'; then
        uri="file://$(${pkgs.coreutils}/bin/realpath "$arg")"
      else
        uri="$arg"
      fi
      exec google-chrome-stable --app="$uri"
    }
    if [ "$#" -ge 1 ]; then
      open_one "$1"
    else
      echo "xdg-open-tabbed: nothing to open" >&2
      exit 1
    fi
  '';
in
{
  home.packages = [
    wrapper
  ];

  xdg.desktopEntries.chrome-app-tabbed = {
    name = "Chrome (app, tabbed)";
    exec = "${wrapper}/bin/xdg-open-tabbed %u";
    terminal = false;
    type = "Application";
    mimeType = [
      # Images
      "image/jpeg"
      "image/png"
      "image/gif"
      "image/webp"
      "image/apng"
      "image/avif"
      "image/svg+xml"
      "image/bmp"
      "image/x-icon"

      # Audio / Video
      "audio/mpeg"
      "audio/mp3"
      "audio/ogg"
      "audio/x-ogg"
      "application/ogg"
      "video/ogg"
      "audio/webm"
      "video/webm"
      "video/mp4"
      "audio/wav"
      "audio/x-wav"
      "audio/flac"

      # Docs
      "application/pdf"
    ];
    noDisplay = true;
  };
}
