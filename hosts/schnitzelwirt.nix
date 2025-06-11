{ config, pkgs, ... }: {
  imports =
    [ # Include the results of the hardware scan.
      ./schnitzelwirt-hardware.nix
      ./common.nix
    ];

}
