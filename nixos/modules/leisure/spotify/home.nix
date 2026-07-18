{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.skynet.module.leisure.spotify.enable {
    home.packages = with pkgs; [ spotify ];

    xdg.mimeApps.defaultApplications = {
      "x-scheme-handler/spotify" = "spotify.desktop";
    };

    sops.secrets.spotify_client_id = {
      key = "spotify_client_id";
      sopsFile = ../../../assets/secrets/secrets.json;
    };

    sops.secrets.spotify_client_secret = {
      key = "spotify_client_secret";
      sopsFile = ../../../assets/secrets/secrets.json;
    };
  };
}
