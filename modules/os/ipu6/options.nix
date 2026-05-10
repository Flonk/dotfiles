{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.os.ipu6 = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
    platform = mkOption {
      type = types.enum [
        "ipu6"
        "ipu6ep"
        "ipu6epmtl"
      ];
      default = "ipu6epmtl";
      description = "IPU6 platform variant: ipu6 (Tiger Lake), ipu6ep (Alder/Raptor Lake), ipu6epmtl (Meteor Lake)";
    };
  };
}
