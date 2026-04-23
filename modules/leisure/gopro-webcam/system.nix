{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.skynet.module.leisure."gopro-webcam";
  adminUser = config.skynet.host.adminUser;
  videoDeviceNumber = 48;

  gopro-script = pkgs.stdenvNoCC.mkDerivation {
    pname = "gopro-webcam";
    version = "0.0.3";

    src = pkgs.fetchFromGitHub {
      owner = "jschmid1";
      repo = "gopro_as_webcam_on_linux";
      rev = "45adee75bad90d4d1c55f29178ca6984e1e48a36";
      # Run `nix build` and replace with the hash reported in the error.
      hash = "sha256-HH3sd92e/Ct6o/frawt/XvcuveieDmMtd7EbGcmj3fE=";
    };

    nativeBuildInputs = [ pkgs.makeWrapper ];

    postPatch = ''
      substituteInPlace gopro \
        --replace-fail "modprobe v4l2loopback exclusive_caps=1 card_label='GoPro' video_nr=42" "modprobe v4l2loopback devices=1 exclusive_caps=1 max_buffers=2 card_label='GoPro' video_nr=42" \
        --replace-fail "modprobe v4l2loopback exclusive_caps=1 card_label='GoPro'\$GOPRO_VIDEO_NUMBER video_nr=\$GOPRO_VIDEO_NUMBER" "modprobe v4l2loopback devices=1 exclusive_caps=1 max_buffers=2 card_label='GoPro'\$GOPRO_VIDEO_NUMBER video_nr=\$GOPRO_VIDEO_NUMBER"
    '';

    installPhase = ''
      runHook preInstall
      install -Dm755 gopro $out/bin/gopro
      wrapProgram $out/bin/gopro \
        --prefix PATH : ${
          lib.makeBinPath [
            pkgs.kmod
            pkgs.iproute2
            pkgs.curl
            pkgs.ffmpeg
          ]
        }
      runHook postInstall
    '';
  };
in
{
  config = lib.mkIf cfg.enable {
    # Make v4l2loopback available for the manual skynet gopro commands.
    boot.extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];
    boot.extraModprobeConfig = ''
      options v4l2loopback devices=1 exclusive_caps=1 max_buffers=2 card_label="GoPro" video_nr=${toString videoDeviceNumber}
    '';

    environment.systemPackages = [ gopro-script ];

    # Give the admin user access to the virtual video device
    users.users.${adminUser}.extraGroups = [ "video" ];

    # Open UDP port for the GoPro stream
    networking.firewall.allowedUDPPorts = lib.mkIf cfg.openFirewall [ 8554 ];

    # Set video group ownership and rw permissions on the loopback device.
    services.udev.extraRules = ''
      KERNEL=="video${toString videoDeviceNumber}", SUBSYSTEM=="video4linux", GROUP="video", MODE="0660"
    '';
  };
}
