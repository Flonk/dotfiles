{ ... }:
{
  config.skynet.whoami.user = "bricky";

  config.skynet.module = {
    core = {
      direnv.enable = true;
      git.enable = true;
      sops.enable = true;
      zsh.enable = true;
    };
    development = { };
  };
}
