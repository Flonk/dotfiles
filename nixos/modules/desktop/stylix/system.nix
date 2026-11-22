{
  pkgs,
  config,
  lib,
  ...
}:
let
  scheme = config.t3os.module.desktop.stylix.scheme;
in
{
  config = lib.mkIf config.t3os.module.desktop.stylix.enable {
    stylix = {
      enable = true;
      base16Scheme = "${pkgs.base16-schemes}/share/themes/${scheme}.yaml";
      image = lib.mkIf (config.t3os.module.desktop.stylix.lockscreenImage != null) config.t3os.module.desktop.stylix.lockscreenImage;
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

    fonts.fontconfig.defaultFonts =
      let
        emoji = lib.mkAfter [ "Noto Color Emoji" ];
      in
      {
        monospace = emoji;
        sansSerif = emoji;
        serif = emoji;
      };
  };
}
