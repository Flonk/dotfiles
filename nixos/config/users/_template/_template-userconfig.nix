{ ... }:
{
  config.skynet.whoami.user = "__USER__";

  config.skynet.module = {
    core = {
      direnv.enable = true;
      git.enable = true;
      sops.enable = true;
      zsh.enable = true;
    };
  };
}
