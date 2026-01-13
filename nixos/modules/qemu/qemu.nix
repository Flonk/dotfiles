{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.skynet.module.system.qemu {
    # Libvirt (QEMU/KVM) + UEFI firmware
    virtualisation.libvirtd = {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
        swtpm.enable = true; # TPM 2.0 (some guests expect it)
      };
    };

    # GUI manager
    programs.virt-manager.enable = true;

    # Autostart the default NAT network
    systemd.services."virtnetwork@default".wantedBy = [ "multi-user.target" ];

    # Add user to libvirtd and kvm groups
    users.users.flo = {
      extraGroups = [
        "libvirtd"
        "kvm"
      ];
    };
  };
}
