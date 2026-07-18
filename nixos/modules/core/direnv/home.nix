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
      # Load nix-direnv stdlib
      source "${pkgs.nix-direnv}/share/nix-direnv/direnvrc"

      # Auto-enable nix in any directory that looks like a nix project
      # and doesn't have its own .envrc.
      if [[ ! -f .envrc ]]; then
        if [[ -f shell.nix ]]; then
          use nix
        elif [[ -f default.nix ]]; then
          use nix
        elif [[ -f flake.nix ]]; then
          use flake
        fi
      fi

      # Still allow project/global overrides higher up the tree
      source_up
    '';
  };
}
