{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.skynet.module.os.ipu6;
  inherit (config.boot.kernelPackages) kernel;

  # intel_cvs: CVS ownership-transfer driver for MTL/ARL/LNL sensors, not
  # upstreamed — see obsidian://claude/video-setup (2026-07-04 entry).
  vision-drivers = pkgs.stdenv.mkDerivation {
    pname = "vision-drivers";
    version = "unstable-2026-05-07";

    src = pkgs.fetchFromGitHub {
      owner = "intel";
      repo = "vision-drivers";
      rev = "845d6f8bdf66ff1f455901da9de5e00a53a83dce";
      hash = "sha256-i/qZN8GXyqaE6n6pRtxQLdmGhmPDjoArzVvflDmwuSs=";
    };

    nativeBuildInputs = kernel.moduleBuildDependencies;

    makeFlags = [
      "KERNELRELEASE=${kernel.modDirVersion}"
      "KERNEL_SRC=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
      "INSTALL_MOD_PATH=$(out)"
      "INSTALL_MOD_STRIP=1"
    ];

    installTargets = [ "modules_install" ];
    enableParallelBuilding = true;
  };

  # In-tree isys rebuilt with the DWC PHY band-overlap fix (accepted upstream,
  # expected in 7.2 — drop once the kernel has it). Installs to updates/ so
  # depmod prefers it over the in-tree module.
  ipu6-isys-phy-fix = pkgs.stdenv.mkDerivation {
    pname = "ipu6-isys-phy-fix";
    version = kernel.version;
    src = kernel.src;

    patches = [ ./dwc-phy-band-overlap.patch ];

    nativeBuildInputs = kernel.moduleBuildDependencies;

    buildPhase = ''
      make -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build \
        M=$PWD/drivers/media/pci/intel/ipu6 modules -j$NIX_BUILD_CORES
    '';

    installPhase = ''
      make -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build \
        M=$PWD/drivers/media/pci/intel/ipu6 \
        INSTALL_MOD_PATH=$out INSTALL_MOD_DIR=updates INSTALL_MOD_STRIP=1 \
        modules_install
    '';
  };
in
{
  config = lib.mkIf cfg.enable {
    hardware.ipu6 = {
      enable = true;
      platform = cfg.platform;
    };

    boot.extraModulePackages = [
      vision-drivers
      ipu6-isys-phy-fix
    ];
    boot.kernelModules = [ "intel_cvs" ];

    systemd.services.v4l2-relayd-ipu6.serviceConfig = {
      # The IPU6 driver historically wedged in D-state on shutdown; keep the
      # stop path short — see obsidian://claude/video-setup.
      TimeoutStopSec = lib.mkForce "1s";
      KillSignal = lib.mkForce "SIGKILL";
      # CamHAL needs real /tmp and leaves a stale SysV shm segment behind.
      PrivateTmp = lib.mkForce false;
      ExecStartPre = [ "-${pkgs.util-linux}/bin/ipcrm -M 0x0043414d" ];
    };
  };
}
