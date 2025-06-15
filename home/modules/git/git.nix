{
  pkgs,
  config,
  lib,
  theme,
  ...
}: {
  
  programs.git = {
    enable = true;

    delta.enable = true;

    extraConfig = {
      core.askPass = "";
      rerere.enabled = true;
      push.autosetupRemote = true;
      fetch.prune = true;
      pull.rebase = true;
      diff.algorithm = "histogram";
    }; 
  };
  
}
