{
  config,
  lib,
  ...
}:
let
  googleChromeMime = import ../google-chrome/mimeApps.nix;
  googleChromeFileViewerMime = import ../google-chrome/file-viewer-mimeApps.nix;
  csvlensMime = import ../csvlens/mimeApps.nix;
  spotifyMime = import ../spotify/mimeApps.nix;
in
{
  config = lib.mkIf config.skynet.mimeapps {
    xdg.mimeApps = {
      enable = true;
      defaultApplications = lib.mkMerge [
        (lib.optionalAttrs config.skynet.module.home.google-chrome googleChromeMime)
        (lib.optionalAttrs config.skynet.module.home.google-chrome googleChromeFileViewerMime)
        (lib.optionalAttrs config.skynet.module.home.csvlens csvlensMime)
        (lib.optionalAttrs config.skynet.module.home.spotify spotifyMime)
      ];
    };
  };
}
