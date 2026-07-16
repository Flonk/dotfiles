{
  pkgs,
  rev ? "dev",
}:
let
  quickshellSrc = builtins.path {
    path = ./quickshell;
    name = "gloxwald-quickshell";
  };
  greeterSrc = builtins.path {
    path = ./greeter;
    name = "gloxwaldgreet-src";
  };
  asciiDefault = builtins.path {
    path = ./ascii.txt;
    name = "gloxwald-ascii.txt";
  };
in
{
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
}
