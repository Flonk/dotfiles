{
  pkgs,
  config,
  lib,
  ...
}:
let
  scheme = config.skynet.module.desktop.stylix.scheme;
in
{
  config = lib.mkIf config.skynet.module.desktop.stylix.enable {
    stylix = {
      enable = true;
      base16Scheme = "${pkgs.base16-schemes}/share/themes/${scheme}.yaml";
      image = lib.mkIf (config.skynet.module.desktop.stylix.lockscreenImage != null) config.skynet.module.desktop.stylix.lockscreenImage;
      fonts = {
        monospace = {
          package = pkgs.nerd-fonts.dejavu-sans-mono;
          name = "DejaVuSansM Nerd Font";
        };
        sansSerif = {
          package = pkgs.nerd-fonts.dejavu-sans-mono;
          name = "DejaVuSansM Nerd Font";
        };
        serif = {
          package = pkgs.nerd-fonts.dejavu-sans-mono;
          name = "DejaVuSansM Nerd Font";
        };
      };
      targets.grub.enable = false;
    };
  };
}
