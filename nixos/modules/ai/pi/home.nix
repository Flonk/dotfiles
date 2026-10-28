{
  pkgs,
  config,
  lib,
  ...
}:
let
  piScript = pkgs.writeShellScriptBin "pi" ''
    export PATH="${pkgs.nodejs}/bin:$PATH"
    export npm_config_ignore_scripts=true
    exec ${pkgs.nodejs}/bin/npx --yes @earendil-works/pi-coding-agent "$@"
  '';
in
{
  config = lib.mkIf config.skynet.module.ai.pi.enable {
    home.packages = [ piScript ];
  };
}
