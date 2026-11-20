{
  pkgs,
  rev ? "dev",
  accent ? "#1d9eb6",
}:
let
  quickshellSrc = builtins.path {
    path = ./src/quickshell;
    name = "gloxwald-quickshell";
  };
  greeterSrc = builtins.path {
    path = ./src/greeter;
    name = "gloxwaldgreet-src";
  };
  asciiDefault = builtins.path {
    path = ./ascii.txt;
    name = "gloxwald-ascii.txt";
  };
  chromeStatic = builtins.path {
    path = ./src/quickshell/shell/chrome;
    name = "gloxwald-chrome-static";
    filter = path: type: builtins.elem (baseNameOf path) [ "dots.png" "noise.png" "grain.png" ];
  };
  chrome = pkgs.runCommand "gloxwald-chrome" {
    nativeBuildInputs = [ (pkgs.python3.withPackages (p: [ p.numpy p.pillow ])) ];
  } ''
    mkdir -p $out
    cp ${chromeStatic}/*.png $out/
    python3 -I ${./dev/bake-chrome.py} '${accent}' $out/gradient.png $out/palette.json
  '';
in
{
  inherit chrome;

  default = pkgs.writeShellApplication {
    name = "gloxwald";
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
    pname = "gloxwaldgreet";
    version = "2.0.0";

    src = greeterSrc;

    vendorHash = "sha256-q6Wi5OiE0E5vr49uq/gYU4xE3oAD4NT87ntxDAXycSk=";

    ldflags = [
      "-X main.Version=${version}"
      "-X main.GitCommit=${rev}"
      "-X main.BuildDate=1970-01-01"
      "-X main.defaultAsciiPath=${placeholder "out"}/share/gloxwaldgreet/ascii.txt"
    ];

    subPackages = [ "cmd/gloxwaldgreet" ];
    buildVcsInfo = false;

    postInstall = ''
      mkdir -p $out/share/gloxwaldgreet
      cp ${asciiDefault} $out/share/gloxwaldgreet/ascii.txt
    '';

    meta = with pkgs.lib; {
      description = "Graphical console greeter for greetd with ASCII art";
      license = licenses.gpl3Only;
      platforms = platforms.linux;
      mainProgram = "gloxwaldgreet";
    };
  };

  hy3 = pkgs.hyprlandPlugins.hy3;
}
