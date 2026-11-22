{
  config,
  lib,
  ...
}:
{
  imports = [ ./vicinae.nix ];

  config = lib.mkIf config.t3os.module.desktop.i18n.enable {
    programs.t3-desktop.i18n = {
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
