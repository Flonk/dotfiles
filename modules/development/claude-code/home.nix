{
  pkgs,
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.skynet.module.development.claude-code.enable {
    home.packages = [
      pkgs.gh
      (pkgs.writeShellScriptBin "claude" ''
        export PATH="${pkgs.nodejs}/bin:$PATH"
        exec ${pkgs.nodejs}/bin/npx --yes @anthropic-ai/claude-code@2.1.76 "$@"
      '')
    ];
  };
}
