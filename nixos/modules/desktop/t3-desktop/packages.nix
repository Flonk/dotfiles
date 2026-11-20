{
  pkgs,
  rev ? "dev",
  accent ? "#1d9eb6",
  ground ? null,
  scheme ? "ayu-dark",
  frameWidth ? 1920,
  frameHeight ? 1200,
}:
let
  quickshellSrc = builtins.path {
    path = ./src/quickshell;
    name = "t3-desktop-quickshell";
  };
  greeterSrc = builtins.path {
    path = ./src/greeter;
    name = "t3greet-src";
  };
  asciiDefault = builtins.path {
    path = ./ascii.txt;
    name = "t3-desktop-ascii.txt";
  };
  chromeStatic = builtins.path {
    path = ./src/quickshell/shell/chrome;
    name = "t3-desktop-chrome-static";
    filter = path: type: builtins.elem (baseNameOf path) [ "dots.png" "noise.png" "grain.png" ];
  };
  chrome = pkgs.runCommand "t3-desktop-chrome" {
    nativeBuildInputs = [ (pkgs.python3.withPackages (p: [ p.numpy p.pillow ])) ];
  } ''
    mkdir -p $out
    cp ${chromeStatic}/*.png $out/
    python3 -I ${./dev/bake-chrome.py} '${accent}' $out/gradient.png $out/palette.json '${if ground == null then "" else ground}'
  '';
  frame = pkgs.runCommand "t3-desktop-frame.png" {
    nativeBuildInputs = [ (pkgs.python3.withPackages (p: [ p.numpy p.pillow ])) ];
  } ''
    python3 -I ${./dev/render-frame.py} ${chrome} ${toString frameWidth} ${toString frameHeight} ${pkgs.nerd-fonts.dejavu-sans-mono}/share/fonts/truetype/NerdFonts/DejaVuSansM/DejaVuSansMNerdFont-Bold.ttf $out
  '';
  plymouthTheme = pkgs.runCommand "t3-desktop-plymouth" {
    nativeBuildInputs = [ (pkgs.python3.withPackages (p: [ p.pillow ])) ];
  } ''
    dir=$out/share/plymouth/themes/t3-desktop
    mkdir -p $dir
    cp ${frame} $dir/frame.png
    cp ${./src/plymouth/t3-desktop.script} $dir/t3-desktop.script
    python3 -I -c "from PIL import Image, ImageDraw; s=8; n=10; im=Image.new('RGBA',(n*s,n*s)); ImageDraw.Draw(im).ellipse((0,0,n*s-1,n*s-1), fill='${accent}'); im.resize((n,n), Image.LANCZOS).save('$dir/dot.png')"
    cat > $dir/t3-desktop.plymouth <<EOF
    [Plymouth Theme]
    Name=t3-desktop
    Description=T3 desktop loading screen
    ModuleName=script

    [script]
    ImageDir=$dir
    ScriptFile=$dir/t3-desktop.script
    EOF
  '';
  accentScheme = pkgs.runCommand "t3-desktop-scheme.yaml" {
    nativeBuildInputs = [ (pkgs.python3.withPackages (p: [ p.numpy p.pillow ])) ];
  } ''
    python3 -I ${./dev/bake-chrome.py} scheme ${pkgs.base16-schemes}/share/themes/${scheme}.yaml '${accent}' $out
  '';
in
{
  inherit chrome;
  inherit accentScheme;
  inherit frame;
  inherit plymouthTheme;

  default = pkgs.writeShellApplication {
    name = "t3-desktop";
    runtimeInputs = with pkgs; [
      bluez
      brightnessctl
      coreutils
      curl
      findutils
      gawk
      gnugrep
      iproute2
      libnotify
      networkmanager
      pipewire
      quickshell
      wl-clipboard
      wireplumber
    ];
    text = ''
      exec quickshell --path ${quickshellSrc}/shell "$@"
    '';
  };

  greeter = pkgs.buildGoModule rec {
    pname = "t3greet";
    version = "2.0.0";

    src = greeterSrc;

    vendorHash = "sha256-q6Wi5OiE0E5vr49uq/gYU4xE3oAD4NT87ntxDAXycSk=";

    ldflags = [
      "-X main.Version=${version}"
      "-X main.GitCommit=${rev}"
      "-X main.BuildDate=1970-01-01"
      "-X main.defaultAsciiPath=${placeholder "out"}/share/t3greet/ascii.txt"
    ];

    subPackages = [ "cmd/t3greet" ];
    buildVcsInfo = false;

    postInstall = ''
      mkdir -p $out/share/t3greet
      cp ${asciiDefault} $out/share/t3greet/ascii.txt
    '';

    meta = with pkgs.lib; {
      description = "Graphical console greeter for greetd with ASCII art";
      license = licenses.gpl3Only;
      platforms = platforms.linux;
      mainProgram = "t3greet";
    };
  };

  hy3 = pkgs.hyprlandPlugins.hy3.overrideAttrs {
    src = builtins.path {
      path = ./src/hy3;
      name = "source";
    };
    NIX_CFLAGS_COMPILE = "-DHY3_CHROME_DIR=\"${chrome}\"";
  };
}
