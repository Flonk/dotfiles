{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.t3os.module.development.vscode.enable = mkOption {
    type = types.bool;
    default = false;
  };
}
