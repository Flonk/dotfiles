{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.development.vscode.enable = mkOption {
    type = types.bool;
    default = false;
  };
}
