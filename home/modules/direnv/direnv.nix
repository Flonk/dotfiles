{
  pkgs,
  config,
  lib,
  theme,
  ...
}: {
  
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;

    config = {
      load_dotenv = true;
      hide_env_diff = true;
      log_format = "-";
      log_filter = "ancestor";
      silent = true;
      warn_timeout = "10s";
      whitelist = {
        prefix = [
          "~/repos"
        ];
      };
    };
    nix-direnv.enable = true;
  };

  home.sessionVariables.DIRENV_LOG_FORMAT = "";

  home.file.".config/direnv/direnvrc".text = ''
    source_up
  '';
  
}
