{
  pkgs,
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.skynet.module.home.git {
    programs.git = {
      enable = true;

      settings = {
        core.askPass = "";
        rerere.enabled = true;
        push.autosetupRemote = true;
        fetch.prune = true;
        pull.rebase = true;
        diff.algorithm = "histogram";
        http.sslVerify = "false";
      };
    };

    programs.delta = {
      enable = true;
      enableGitIntegration = true;
    };
  };
}
