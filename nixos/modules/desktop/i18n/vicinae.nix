{
  pkgs,
  inputs,
  config,
  lib,
  ...
}:
let
  cfg = config.skynet.module.desktop.i18n;

  extension = inputs.vicinae.lib.${pkgs.stdenv.hostPlatform.system}.mkVicinaeExtension {
    name = "vicinae-i18n";
    version = "0.1.0";
    src = ./extension;
  };
in
{
  config = lib.mkIf (cfg.enable && config.programs.gloxwald.vicinae.enable) {
    programs.vicinae.extensions = [ extension ];
  };
}
