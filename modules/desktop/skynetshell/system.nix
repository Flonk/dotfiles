{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.skynet.module.desktop.skynetshell;
  s = config.lib.stylix.colors.withHashtag;
  border = config.skynet.module.desktop.stylix.accent;
  asciiArt = builtins.readFile ./skynetgreet-ascii.txt;
in
{
  config = lib.mkIf cfg.enable {
    programs.skynetshell.theme = {
      inherit asciiArt;
      name        = "skynet-stylix";
      bg_base     = s.base00;
      bg_active   = s.base01;
      primary     = s.base0D;
      secondary   = s.base0E;
      accent      = border;
      warning     = s.base0A;
      danger      = s.base08;
      fg_primary   = s.base05;
      fg_secondary = s.base04;
      fg_muted     = s.base03;
      border_focus = border;
    };

    programs.skynetshell.greeter = {
      enable = true;
      settings = {
        exec = "start-hyprland >/dev/null 2>&1";
        effect = "beams";
      };
      font = {
        name = config.stylix.fonts.monospace.name;
        size = 22;
        package = config.stylix.fonts.monospace.package;
      };
    };
  };
}
