{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.skynet.module.ollama.enable {
    services.ollama = {
      enable = true;
      # Use CUDA package for NVIDIA GPU acceleration (Quadro T2000)
      package = pkgs.ollama-cuda;
    };
  };
}
