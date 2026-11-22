{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.skynet.module.development.qemu.enable {
    virtualisation.libvirtd = {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
        swtpm.enable = true;
      };
    };

    systemd.services.libvirtd.wantedBy = lib.mkForce [ ];
    systemd.services.libvirt-guests.wantedBy = lib.mkForce [ ];

    programs.virt-manager.enable = true;

    systemd.services."virtnetwork@default".wantedBy = [ "multi-user.target" ];

    users.users.flo = {
      extraGroups = [
        "libvirtd"
        "kvm"
      ];
    };
  };
}
