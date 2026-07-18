{
  pkgs,
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.skynet.module.core.git.enable {
    programs.git = {
      enable = true;

      settings = {
        user.name = "Florian Schindler";
        user.email = "florian.schindler@andamp.io";
        core.askPass = "";
        rerere.enabled = true;
        push.autosetupRemote = true;
        fetch.prune = true;
        pull.rebase = true;
        diff.algorithm = "histogram";
        init.defaultBranch = "main";
        http.sslVerify = "false";
      };
    };

    programs.delta = {
      enable = true;
      enableGitIntegration = true;
    };
  };
}
