{
  pkgs,
  config,
  lib,
  ...
}:
let
  pname = "photocraft";
  version = "0.5.0";
  src = pkgs.fetchurl {
    url = "https://github.com/storytold/photocraft/releases/download/v${version}/photocraft-${version}-linux-x86_64.AppImage";
    sha256 = "f54d863807053bbdfcffa0d624ef7e49d3fd41310c7bb1ede48536f69929d22f";
  };
  contents = pkgs.appimageTools.extract { inherit pname version src; };
  photocraft = pkgs.appimageTools.wrapType2 {
    inherit pname version src;
    nativeBuildInputs = [ pkgs.makeWrapper ];
    extraInstallCommands = ''
      wrapProgram $out/bin/photocraft --set PHOTOCRAFT_NO_DESKTOP_INTEGRATION 1
      cp -r ${contents}/usr/share $out/share
    '';
  };
in
{
  config = lib.mkIf config.skynet.module.leisure.photocraft.enable {
    home.packages = [ photocraft ];

    xdg.mimeApps.defaultApplications = lib.genAttrs [
      "image/vnd.adobe.photoshop"
      "image/x-psd"
      "image/x-psb"
      "application/x-photocraft"
    ] (_: "ai.storyteller.photocraft.desktop");
  };
}
