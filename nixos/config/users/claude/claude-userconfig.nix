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
    ai = {
      claude-code = {
        enable = true;
        service.enable = true;
      };
    };
    development = {
      obsidian.enable = true;
    };
    projects.andamp.doubletunnel = true;
  };
}
