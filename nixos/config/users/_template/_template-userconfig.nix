{ ... }:
{
  config.t3os.whoami.user = "__USER__";

  config.t3os.module = {
    core = {
      direnv.enable = true;
      git.enable = true;
      sops.enable = true;
      zsh.enable = true;
    };
  };
}
