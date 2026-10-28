{
  pkgs,
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.skynet.module.development."copilot-cli".enable {
    home.packages = [ pkgs.github-copilot-cli ];

    programs.zsh.shellAliases.co = "copilot";
  };
}
