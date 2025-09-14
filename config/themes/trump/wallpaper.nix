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
  enableSwatches ? true,
}:

let
  swatchW = 20;
  swatchH = swatchW;
  swatchGap = 1;

  canvasW = 5120;
  canvasH = 1440;

  padding = 20;

  pointKeys = colorUtils.paletteShades;
  pointKeysDesc = lib.reverseList pointKeys;
in
pkgs.runCommand "../../assets/wallpapers/company_wallpaper.png"
  { buildInputs = [ pkgs.imagemagick ]; }
  (
    let
      # IMPORTANT: tokens are raw (no quotes) so `read -a` splits correctly
      wmColors = lib.concatStringsSep " " (map (k: colorWm.${k}) pointKeys);
      appColors = lib.concatStringsSep " " (map (k: colorApp.${k}) pointKeys);
      # Use only the three configured error shades (high L -> low L): 600, 400, 300
      errColors = lib.concatStringsSep " " [
        colorError600
        colorError400
        colorError300
      ];
      keysJoined = lib.concatStringsSep " " pointKeys;

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

      # Deterministic seed so noise is stable for the same inputs
      randomSeed = toString (canvasW + canvasH + padding + swatchW + swatchGap);
      # Removed iconRandomSeed; not needed with global noise multiply approach
    in
    ''
      set -euo pipefail

      # Tunables for blurred overlay
      ICON_SIZE=150
      BLUR_SIGMA=25
      BLUR_ANGLE=60
      BLUR_ANGLE2=$(( (BLUR_ANGLE + 180) % 360 ))
      # Make blurred layer N (= sigma) pixels bigger on each side of the icon
      EXTENT=$(( ICON_SIZE + 2 * BLUR_SIGMA ))

      # Noise layer controls (near-white range so multiply is subtle)
      NOISE_ATTENUATION=0.06

      # === Base canvas: flat APP 200 ===
      magick -size ${toString canvasW}x${toString canvasH} canvas:"${colorApp."200"}" base.png

      # === Blurred, tinted lockscreen overlay (bidirectional), ~40% opacity ===
      magick base.png \
        \( \
          \( ${lockscreenImage} -trim +repage -resize "''${ICON_SIZE}x''${ICON_SIZE}" \
             -channel rgba -fill "${colorWm."800"}" -colorize 100% \
             -background none -gravity center -extent "''${EXTENT}x''${EXTENT}" \
             -virtual-pixel transparent -motion-blur 0x"''${BLUR_SIGMA}"+"''${BLUR_ANGLE}" \) \
          \( ${lockscreenImage} -trim +repage -resize "''${ICON_SIZE}x''${ICON_SIZE}" \
             -channel rgba -fill "${colorWm."800"}" -colorize 100% \
             -background none -gravity center -extent "''${EXTENT}x''${EXTENT}" \
             -virtual-pixel transparent -motion-blur 0x"''${BLUR_SIGMA}"+"''${BLUR_ANGLE2}" \) \
          -evaluate-sequence mean \
        \) \
        -gravity center -compose dissolve -define compose:args=30 -composite \
        base.png


      # === Global noise multiply overlay (subtle texture) ===
      # Generate near-white Gaussian noise with low amplitude; convert to gray to avoid color tint, then back to sRGB
      magick base.png \
      \( -size ${toString canvasW}x${toString canvasH} xc:gray50 \
        +noise Gaussian \
        -define random-seed=${randomSeed} \
        -colorspace Gray -colorspace sRGB \
        -gaussian-blur 0x0.7 \
        -alpha set -channel a -evaluate set 100% +channel \) \
      -compose overlay -composite base.png

      # === Sharp lockscreen overlay (no blur, original colors) ===
      magick base.png \
        \( ${lockscreenImage} -channel rgba -fill "${colorWm."800"}" -colorize 100% -resize 150x150 \) \
        -gravity center -compose over -composite \
        base.png

      ${
        if enableSwatches then
          ''
            # === Arrays from Nix → bash ===
            read -r -a KEYS      <<< ${lib.escapeShellArg keysJoined}
            read -r -a WM        <<< ${lib.escapeShellArg wmColors}
            read -r -a APP       <<< ${lib.escapeShellArg appColors}
            read -r -a ERR       <<< ${lib.escapeShellArg errColors}

            # Working image
            cp base.png work.png

            # === Layout ===
            W=${toString swatchW}
            H=${toString swatchH}
            GAP=${toString swatchGap}

            # Top-left of the visible monitor region on the big canvas (after scale+crop)
            BASE_X=${baseX}
            BASE_Y=${baseY}

            # Two columns: left = wm, right = app
            for i in ''${!KEYS[@]}; do
              color_left="''${WM[$i]}"
              color_right="''${APP[$i]}"

              # Swatch tiles (opaque, no border)
              magick -size "''${W}x''${H}" canvas:"$color_left" sw-wm-"$i".png
              magick -size "''${W}x''${H}" canvas:"$color_right" sw-app-"$i".png

              # Row/col positions (absolute coords on the big canvas)
              row_y=$(( BASE_Y + i * (H + GAP) ))
              x_left=$(( BASE_X ))
              x_right=$(( BASE_X + W + GAP ))

              # Composite at absolute coords from top-left of the canvas
              magick composite -gravity northwest -geometry +''${x_left}+''${row_y}  sw-wm-"$i".png  work.png work.png
              magick composite -gravity northwest -geometry +''${x_right}+''${row_y} sw-app-"$i".png work.png work.png
            done

            # === Error swatches (top-right, 600 -> 400 -> 300, horizontally) ===
            ERR_START_X=${errStartX}
            ERR_Y=${baseY}
            for i in ''${!ERR[@]} ; do
              color_err="''${ERR[$i]}"
              magick -size "''${W}x''${H}" canvas:"$color_err" sw-err-"$i".png
              x=$(( ERR_START_X + i * (W + GAP) ))
              y=''${ERR_Y}
              magick composite -gravity northwest -geometry +''${x}+''${y} sw-err-"$i".png work.png work.png
            done

            mv work.png $out
          ''
        else
          ''
            # Swatches disabled
            cp base.png $out
          ''
      }
    ''
  )
