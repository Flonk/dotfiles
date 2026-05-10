{ ... }:
{
  config.skynet.whoami.user = "claude";

  config.skynet.module = {
    core = {
      direnv.enable = true;
      git.enable = true;
      sops.enable = true;
      zsh.enable = true;
    };
    desktop = {
      stylix.enable = true;
    };
    development = {
      claude-code = {
        enable = true;
        service.enable = true;
      };
    };
  };
}
