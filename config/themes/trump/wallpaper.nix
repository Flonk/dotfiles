{
  lib,
  pkgs,
  config,
  colorWm,
  colorApp,
  colorUtils,
  lockscreenImage,
  colorError600,
  colorError400,
  colorError300,
  colorError800,
  colorSuccess400,
  colorSuccess600,
  colorSuccess800,
  enableSwatches ? true,
}:

let
  imagemagick = pkgs.imagemagick; # IM7 ("magick")

  swatchW = 20;
  swatchH = swatchW;
  swatchGap = 1;

  canvasW = 5120;
  canvasH = 1440;

  padding = 20;

  # Monitor dims
  mw = config.hostconfig.primaryMonitor.width;
  mh = config.hostconfig.primaryMonitor.height;

  # Scale canvas to monitor height, then crop width centrally (use float math)
  scale = (1.0 * mh) / (1.0 * canvasH);
  scaledW = canvasW * scale;
  scaledH = canvasH * scale;

  # Convert padding to canvas-space so it stays constant on the monitor
  padC = (1.0 * padding) / scale;

  # Offsets in scaled space, then convert back to original canvas coords
  baseX = toString (builtins.floor (((scaledW - mw) / 2.0) / scale + padC));
  baseY = toString (builtins.floor (((scaledH - mh) / 2.0) / scale + padC));

  # Top-right start X for the 3 error swatches (canvas space)
  visibleLeftC = ((scaledW - mw) / 2.0) / scale;
  visibleWidthC = mw / scale;
  errTotalW = 3 * swatchW + 2 * swatchGap;
  errStartX = toString (builtins.floor (visibleLeftC + visibleWidthC - padC - errTotalW));

  pointKeys = colorUtils.paletteShades;

  wmColors = map (k: colorWm.${k}) pointKeys;
  appColors = map (k: colorApp.${k}) pointKeys;
  errColors = [
    colorError600
    colorError400
    colorError300
  ];

  # Deterministic seed so noise is stable for the same inputs
  randomSeed = canvasW + canvasH + padding + swatchW + swatchGap;

  mkNoise =
    {
      w,
      h,
      seed ? 1234,
    }:
    pkgs.runCommand "noise.png" { buildInputs = [ imagemagick ]; } ''
      set -euo pipefail
      magick -size ${toString w}x${toString h} xc:gray50 \
        +noise Gaussian -define random-seed=${toString seed} \
        -colorspace Gray -colorspace sRGB \
        -gaussian-blur 0x0.7 -type TrueColorAlpha png32:$out
    '';

  mkSharpLogo =
    {
      img,
      hex,
      size ? 150,
    }:
    pkgs.runCommand "logo-sharp.png" { buildInputs = [ imagemagick ]; } ''
      set -euo pipefail
      magick ${img} -trim +repage -resize ${toString size}x${toString size} \
        -channel rgba -fill "${hex}" -colorize 100% \
        -set colorspace sRGB -alpha set -type TrueColorAlpha png32:$out
    '';

  mkSwatches =
    {
      w,
      h,
      gap,
      baseX,
      baseY,
      errStartX,
      wmColors,
      appColors,
      errColors,
      enable ? true,
    }:
    if !enable then
      pkgs.runCommand "swatches-empty" { buildInputs = [ imagemagick ]; } ''
        magick -size 1x1 xc:none -set colorspace sRGB -alpha set -type TrueColorAlpha png32:$out
      ''
    else
      pkgs.runCommand "swatches-bundle" { buildInputs = [ imagemagick ]; } (
        let
          keysJoined = lib.concatStringsSep " " pointKeys;
          wmJoined = lib.concatStringsSep " " wmColors;
          appJoined = lib.concatStringsSep " " appColors;
          errJoined = lib.concatStringsSep " " errColors;
          rows = builtins.length pointKeys;
          sheetW = 2 * w + gap;
          sheetH = rows * h + (rows - 1) * gap;
          errW = 3 * w + 2 * gap;
          errH = h;
        in
        ''
          set -euo pipefail

          read -r -a KEYS <<< ${lib.escapeShellArg keysJoined}
          read -r -a WM   <<< ${lib.escapeShellArg wmJoined}
          read -r -a APP  <<< ${lib.escapeShellArg appJoined}
          read -r -a ERR  <<< ${lib.escapeShellArg errJoined}

          W=${toString w}; H=${toString h}; GAP=${toString gap}
          SHEET_W=${toString sheetW}; SHEET_H=${toString sheetH}
          ERR_W=${toString errW};     ERR_H=${toString errH}

          magick -size "''${SHEET_W}x''${SHEET_H}" xc:none \
            -set colorspace sRGB -alpha set -type TrueColorAlpha png32:main.png

          for i in ''${!KEYS[@]}; do
            cL="''${WM[$i]}"; cR="''${APP[$i]}"
            row_y=$(( i * (H + GAP) ))

            magick -size "''${W}x''${H}" xc:none \
              -set colorspace sRGB -alpha set \
              -fill "$cL" -draw "color 0,0 floodfill" \
              -type TrueColorAlpha +dither -define png:color-type=6 png32:tileL.png

            magick -size "''${W}x''${H}" xc:none \
              -set colorspace sRGB -alpha set \
              -fill "$cR" -draw "color 0,0 floodfill" \
              -type TrueColorAlpha +dither -define png:color-type=6 png32:tileR.png

            magick composite -gravity northwest -geometry +0+''${row_y}              tileL.png main.png main.png
            magick composite -gravity northwest -geometry +$((W+GAP))+''${row_y}     tileR.png main.png main.png
          done

          magick -size "''${ERR_W}x''${ERR_H}" xc:none \
            -set colorspace sRGB -alpha set -type TrueColorAlpha png32:err.png

          for i in ''${!ERR[@]}; do
            cE="''${ERR[$i]}"; x=$(( i * (W + GAP) ))
            magick -size "''${W}x''${H}" xc:none \
              -set colorspace sRGB -alpha set \
              -fill "$cE" -draw "color 0,0 floodfill" \
              -type TrueColorAlpha +dither -define png:color-type=6 png32:tileE.png

            magick composite -gravity northwest -geometry +''${x}+0 tileE.png err.png err.png
          done

          mkdir -p $out
          cp main.png "$out/main.png"
          cp err.png  "$out/err.png"
        ''
      );

  noiseLayer = mkNoise {
    w = canvasW;
    h = canvasH;
    seed = randomSeed;
  };

  sharpLogo = mkSharpLogo {
    img = lockscreenImage;
    hex = colorWm."800";
    size = 150;
  };

  swatchLayer = mkSwatches {
    w = swatchW;
    h = swatchH;
    gap = swatchGap;
    baseX = baseX;
    baseY = baseY;
    errStartX = errStartX;
    wmColors = wmColors;
    appColors = appColors;
    errColors = errColors;
    enable = enableSwatches;
  };

in
pkgs.runCommand "../../assets/wallpapers/company_wallpaper.png" { buildInputs = [ imagemagick ]; }
  ''
    set -euo pipefail

    magick \
      -size ${toString canvasW}x${toString canvasH} canvas:"${colorApp."200"}" \
      \( ${noiseLayer} \)  -compose overlay -composite \
      \( ${sharpLogo} \)   -gravity center -compose over -composite \
      -gravity northwest \
      \( ${swatchLayer}/main.png \) -geometry +${baseX}+${baseY}     -compose over -composite \
      \( ${swatchLayer}/err.png  \) -geometry +${errStartX}+${baseY} -compose over -composite \
      -alpha off -strip \
      -define png:compression-level=3 -define zlib:compression-level=3 -define png:exclude-chunks=time,date \
      png32:$out
  ''
