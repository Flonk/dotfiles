{ ... }:
{
  config.skynet.whoami.user = "claude";

  config.skynet.module = {
    core = {
      direnv.enable = true;
      eventbus = {
        enable = true;
        ui = false;
        userBroker = true;
      };
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
    projects.andamp = {
      CEIFRS = true;
      crdpBackend = "xvfb";
      doubletunnel = true;
    };
  };
}
