{ ... }:
{
  config.skynet.module = {
    core = {
      direnv.enable = true;
      zsh.enable = true;
    };
    development = {
      zeroclaw.enable = true;
    };
  };
}
