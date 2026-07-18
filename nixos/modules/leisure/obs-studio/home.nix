{
  pkgs,
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.skynet.module.leisure."obs-studio".enable {
    programs.obs-studio = {
      enable = true;

      # optional Nvidia hardware acceleration
      package = (
        pkgs.obs-studio.override {
          cudaSupport = true;
        }
      );

      plugins = with pkgs.obs-studio-plugins; [
        wlrobs
        obs-backgroundremoval
        obs-pipewire-audio-capture
        obs-gstreamer
        obs-vkcapture
      ];
    };
  };
}
