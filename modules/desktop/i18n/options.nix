{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.desktop.i18n = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };

    defaultLayout = mkOption {
      type = types.str;
      default = "de";
    };

    inputMethods = mkOption {
      type = types.listOf (
        types.submodule {
          options = {
            im = mkOption { type = types.str; };
            label = mkOption { type = types.str; };
            layout = mkOption {
              type = types.str;
              default = "";
            };
          };
        }
      );
      default = [
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
