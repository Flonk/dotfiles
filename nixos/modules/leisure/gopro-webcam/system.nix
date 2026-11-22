{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.skynet.module.leisure."gopro-webcam";
  adminUser = config.skynet.host.adminUser;

  gopro-webcam = pkgs.buildNpmPackage {
    pname = "gopro-webcam";
    version = "1.0.0";
    src = ./.;
    npmDepsHash = "sha256-+4S6Yhord1M+bGbGlaTR/KCta7kxkwueksbPLADzf5o=";
    dontNpmBuild = true;

    nativeBuildInputs = [ pkgs.makeWrapper ];

    postInstall = ''
      mkdir -p $out/bin
      local pkg="$out/lib/node_modules/gopro-webcam"
      makeWrapper "$pkg/node_modules/.bin/tsx" "$out/bin/gopro-webcam" \
        --add-flags "$pkg/src/gopro.tsx" \
        --prefix PATH : ${
          lib.makeBinPath [
            pkgs.ffmpeg
            pkgs.curl
            pkgs.iproute2
            pkgs.kmod
            pkgs.procps
            pkgs.libnotify
            config.boot.kernelPackages.v4l2loopback.bin
          ]
        }
    '';
  };
in
{
  config = lib.mkIf cfg.enable {
    boot.extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];

    environment.systemPackages = [
      gopro-webcam
      pkgs.ffmpeg
      config.boot.kernelPackages.v4l2loopback.bin
    ];

    users.users.${adminUser}.extraGroups = lib.mkIf (adminUser != null) [ "video" ];

    networking.firewall.allowedUDPPorts = lib.mkIf cfg.openFirewall [ 8554 ];

    services.udev.extraRules = ''
      SUBSYSTEM=="video4linux", ATTR{name}=="*GoPro*", GROUP="video", MODE="0660"
    '' + lib.optionalString cfg.autoStart ''
      ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="2672", ATTR{idProduct}=="0059", RUN+="${pkgs.systemd}/bin/systemctl start --no-block gopro-webcam-start.service"
      ACTION=="remove", SUBSYSTEM=="usb", ENV{PRODUCT}=="2672/59/*", RUN+="${pkgs.systemd}/bin/systemctl start --no-block gopro-webcam-stop.service"
    '';

    systemd.services.gopro-webcam-start = lib.mkIf cfg.autoStart {
      description = "Start GoPro webcam";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${gopro-webcam}/bin/gopro-webcam start";
        KillMode = "process";
        Environment = [
          "GOPRO_USER=${adminUser}"
        ];
      };
      path = [
        gopro-webcam
        pkgs.bashInteractive
        pkgs.ffmpeg
        pkgs.systemd
        pkgs.util-linux
        config.boot.kernelPackages.v4l2loopback.bin
      ];
    };

    systemd.services.gopro-webcam-stop = lib.mkIf cfg.autoStart {
      description = "Stop GoPro webcam";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${gopro-webcam}/bin/gopro-webcam stop";
        Environment = [
          "GOPRO_USER=${adminUser}"
        ];
      };
      path = [
        gopro-webcam
        pkgs.util-linux
      ];
    };
  };
}
