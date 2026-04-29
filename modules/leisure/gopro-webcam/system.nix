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

    # buildNpmPackage places output in lib/node_modules/gopro-webcam/.
    # Create a wrapper that calls tsx with the right PATH for runtime tools.
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
    # Make v4l2loopback available (loaded on demand, not at boot).
    boot.extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];

    # The gopro-webcam script and tools it calls via sudo must be on the system PATH.
    environment.systemPackages = [
      gopro-webcam
      pkgs.ffmpeg
      config.boot.kernelPackages.v4l2loopback.bin
    ];

    # Give the admin user access to the virtual video device.
    users.users.${adminUser}.extraGroups = lib.mkIf (adminUser != null) [ "video" ];

    # Open UDP port for the GoPro stream.
    networking.firewall.allowedUDPPorts = lib.mkIf cfg.openFirewall [ 8554 ];

    # Set video group ownership and rw permissions on any v4l2loopback device.
    # Auto-start/stop when GoPro is plugged/unplugged (Hero 11 Black: 2672:0059).
    services.udev.extraRules = ''
      SUBSYSTEM=="video4linux", ATTR{name}=="*GoPro*", GROUP="video", MODE="0660"
    '' + lib.optionalString cfg.autoStart ''
      ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="2672", ATTR{idProduct}=="0059", RUN+="${pkgs.systemd}/bin/systemctl start --no-block gopro-webcam-start.service"
      ACTION=="remove", SUBSYSTEM=="usb", ENV{ID_VENDOR_ID}=="2672", ENV{ID_MODEL_ID}=="0059", RUN+="${pkgs.systemd}/bin/systemctl start --no-block gopro-webcam-stop.service"
    '';

    # Systemd services for udev-triggered auto start/stop.
    systemd.services.gopro-webcam-start = lib.mkIf cfg.autoStart {
      description = "Start GoPro webcam";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${gopro-webcam}/bin/gopro-webcam start";
        Environment = [
          "GOPRO_USER=${adminUser}"
        ];
      };
      path = [
        gopro-webcam
        pkgs.bashInteractive
        pkgs.ffmpeg
        pkgs.util-linux # runuser
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
