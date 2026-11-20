{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.skynet.module.leisure.artcraft;
  versions = lib.importJSON ./versions.json;
  jq = "${pkgs.jq}/bin/jq";

  mkCraft =
    {
      pname,
      wrapperArgs ? "",
    }:
    let
      inherit (versions.${pname}) version hash;
      src = pkgs.fetchurl {
        url = "https://github.com/storytold/${pname}/releases/download/v${version}/${pname}-${version}-linux-x86_64.AppImage";
        inherit hash;
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
    wrapperArgs = "--set PHOTOCRAFT_NO_DESKTOP_INTEGRATION 1";
  };

  filmcraft = mkCraft {
    pname = "filmcraft";
  };

  vectorcraft = mkCraft {
    pname = "vectorcraft";
  };

  updater = pkgs.writeShellScript "artcraft-update.sh" ''
    set -euo pipefail
    file="$SKYNET_REPO/nixos/modules/leisure/artcraft/versions.json"
    for app in ${lib.concatStringsSep " " (builtins.attrNames versions)}; do
      current=$(${jq} -r --arg a "$app" '.[$a].version' "$file")
      latest=$(${pkgs.curl}/bin/curl -fsSL "https://api.github.com/repos/storytold/$app/releases/latest" | ${jq} -r '.tag_name | ltrimstr("v")')
      if [[ "$current" == "$latest" ]]; then
        echo "$app: $current (up to date)"
        continue
      fi
      url="https://github.com/storytold/$app/releases/download/v$latest/$app-$latest-linux-x86_64.AppImage"
      hash=$(nix store prefetch-file --json "$url" | ${jq} -r .hash)
      tmp=$(mktemp)
      ${jq} --arg a "$app" --arg v "$latest" --arg h "$hash" '.[$a] = {version: $v, hash: $h}' "$file" > "$tmp"
      mv "$tmp" "$file"
      echo "$app: $current -> $latest"
    done
  '';
in
{
  config = lib.mkMerge [
    (lib.mkIf (cfg.photocraft.enable || cfg.filmcraft.enable || cfg.vectorcraft.enable) {
      skynet.cli.updaters = [
        {
          name = "artcraft";
          script = updater;
        }
      ];
    })
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
