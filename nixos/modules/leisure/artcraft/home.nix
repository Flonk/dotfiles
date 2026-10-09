{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.skynet.module.leisure.artcraft;

  mkCraft =
    {
      pname,
      version,
      sha256,
      wrapperArgs ? "",
    }:
    let
      src = pkgs.fetchurl {
        url = "https://github.com/storytold/${pname}/releases/download/v${version}/${pname}-${version}-linux-x86_64.AppImage";
        inherit sha256;
      };
      contents = pkgs.appimageTools.extract { inherit pname version src; };
    in
    pkgs.appimageTools.wrapType2 {
      inherit pname version src;
      nativeBuildInputs = [ pkgs.makeWrapper ];
      extraInstallCommands = ''
        ${lib.optionalString (wrapperArgs != "") "wrapProgram $out/bin/${pname} ${wrapperArgs}"}
        cp -r ${contents}/usr/share $out/share
      '';
    };

  photocraft = mkCraft {
    pname = "photocraft";
    version = "0.5.0";
    sha256 = "f54d863807053bbdfcffa0d624ef7e49d3fd41310c7bb1ede48536f69929d22f";
    wrapperArgs = "--set PHOTOCRAFT_NO_DESKTOP_INTEGRATION 1";
  };

  filmcraft = mkCraft {
    pname = "filmcraft";
    version = "0.4.0";
    sha256 = "d8410dea7b2b064ede1ead87dd894bca3537a4dfda1a44297158849f56ba2d4c";
  };

  vectorcraft = mkCraft {
    pname = "vectorcraft";
    version = "0.7.0";
    sha256 = "f6928f9adf423ad0a145ebfe3b142a95d3d26f550b05249c2012145701f98b60";
  };
in
{
  config = lib.mkMerge [
    (lib.mkIf cfg.photocraft.enable {
      home.packages = [ photocraft ];

      xdg.mimeApps.defaultApplications = lib.genAttrs [
        "image/vnd.adobe.photoshop"
        "image/x-psd"
        "image/x-psb"
        "application/x-photocraft"
      ] (_: "ai.storyteller.photocraft.desktop");
    })
    (lib.mkIf cfg.filmcraft.enable {
      home.packages = [ filmcraft ];
    })
    (lib.mkIf cfg.vectorcraft.enable {
      home.packages = [ vectorcraft ];
    })
  ];
}
