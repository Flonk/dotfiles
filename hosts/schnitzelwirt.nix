{ config, pkgs, ... }: {
  imports =
    [
      ./schnitzelwirt-hardware.nix
      ./common.nix
    ];

  networking.hostName = "schnitzelwirt";
}
