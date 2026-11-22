{
  pkgs,
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.skynet.module.core.direnv.enable {
    programs.direnv = {
      enable = true;
      enableZshIntegration = true;
      enableBashIntegration = true;

      nix-direnv.enable = true;

      config = {
        load_dotenv = true;
        hide_env_diff = true;
        log_format = "-";
        log_filter = "ancestor";
        silent = true;
        warn_timeout = "10s";
        whitelist.prefix = [ "~/repos" ];
      };
    };

    home.sessionVariables.DIRENV_LOG_FORMAT = "";

    home.file.".config/direnv/direnvrc".text = ''
      source "${pkgs.nix-direnv}/share/nix-direnv/direnvrc"

      if [[ ! -f .envrc ]]; then
        if [[ -f shell.nix ]]; then
          use nix
        elif [[ -f default.nix ]]; then
          use nix
        elif [[ -f flake.nix ]]; then
          use flake
        fi
      fi

      source_up
    '';
  };
}
