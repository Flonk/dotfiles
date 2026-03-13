{
  config,
  lib,
  ...
}:
let
  googleChromeMime = import ../google-chrome/mimeApps.nix;
  googleChromeFileViewerMime = import ../google-chrome/file-viewer-mimeApps.nix;
  csvlensMime = import ../csvlens/mimeApps.nix;
  spotifyMime = import ../../leisure/spotify/mimeApps.nix;
in
{
  config = lib.mkIf config.skynet.mimeapps {
    xdg.mimeApps = {
      enable = true;
      defaultApplications = lib.mkMerge [
        (lib.optionalAttrs config.skynet.module.google-chrome.enable googleChromeMime)
        (lib.optionalAttrs config.skynet.module.google-chrome.enable googleChromeFileViewerMime)
        (lib.optionalAttrs config.skynet.module.csvlens.enable csvlensMime)
        (lib.optionalAttrs config.skynet.module.spotify.enable spotifyMime)
      ];
    };
  };
}
