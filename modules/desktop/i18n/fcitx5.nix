{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.skynet.module.desktop.i18n;

  imItems = lib.listToAttrs (
    lib.imap0 (
      i: m:
      lib.nameValuePair "Groups/0/Items/${toString i}" (
        {
          Name = m.im;
        }
        // lib.optionalAttrs (m.layout != "") { Layout = m.layout; }
      )
    ) cfg.inputMethods
  );
in
{
  config = lib.mkIf cfg.enable {
    i18n.inputMethod = {
      enable = true;
      type = "fcitx5";
      fcitx5 = {
        waylandFrontend = true;
        addons = with pkgs; [
          qt6Packages.fcitx5-chinese-addons
          fcitx5-gtk
        ];
        settings.globalOptions."Hotkey/TriggerKeys" = { };
        settings.inputMethod = {
          GroupOrder."0" = "Default";
          "Groups/0" = {
            Name = "Default";
            "Default Layout" = cfg.defaultLayout;
            DefaultIM = (builtins.head cfg.inputMethods).im;
          };
        }
        // imItems;
      };
    };
  };
}
