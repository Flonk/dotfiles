{
  pkgs,
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.t3os.module.ai."copilot-cli".enable {
    home.packages = [ pkgs.github-copilot-cli ];

    programs.zsh.shellAliases.co = "copilot";
  };
}
