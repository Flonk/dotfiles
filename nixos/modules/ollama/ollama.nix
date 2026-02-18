{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.skynet.module.system.ollama {
    services.ollama = {
      enable = true;
    };
  };
}
