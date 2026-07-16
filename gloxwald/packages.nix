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
    version = "1.0.7";

    src = greeterSrc;

    vendorHash = "sha256-W0Hs8tVr1Z5Qx2pbeGiwx8ow3nDDp+K9xFSQPn1Fo/E=";

    ldflags = [
      "-X main.Version=${version}"
      "-X main.GitCommit=${rev}"
      "-X main.BuildDate=1970-01-01"
      "-X main.dataDir=${placeholder "out"}/share/gloxwaldgreet"
    ];

    subPackages = [ "cmd/gloxwaldgreet" ];
    buildVcsInfo = false;

    postInstall = ''
      mkdir -p $out/share/gloxwaldgreet/ascii_configs
      cp -r ascii_configs/* $out/share/gloxwaldgreet/ascii_configs/
    '';

    meta = with pkgs.lib; {
      description = "Graphical console greeter for greetd with ASCII art and themes";
      license = licenses.gpl3Only;
      platforms = platforms.linux;
      mainProgram = "gloxwaldgreet";
    };
  };
}
