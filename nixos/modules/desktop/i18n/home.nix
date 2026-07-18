{
  config,
  lib,
  ...
}:
{
  imports = [ ./vicinae.nix ];

  config = lib.mkIf config.skynet.module.desktop.i18n.enable {
    programs.gloxwald.i18n = {
      enable = true;
      defaultLayout = "de";
      inputMethods = [
        {
          im = "keyboard-de";
          label = "GERMAN";
        }
        {
          im = "pinyin";
          label = "CHINESE";
        }
      ];
    };
  };
}
