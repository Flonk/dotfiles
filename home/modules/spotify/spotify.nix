{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.skynet.module.home.spotify {
    home.packages = with pkgs; [ spotify ];

    xdg.mimeApps = lib.mkIf config.skynet.mimeapps {
      defaultApplications = import ./mimeApps.nix;
    };
  };
}
