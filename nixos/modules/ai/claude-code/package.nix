{ pkgs }:
pkgs.writeShellScriptBin "claude" ''
  export PATH="${pkgs.nodejs}/bin:$PATH"
  exec ${pkgs.nodejs}/bin/npx --yes @anthropic-ai/claude-code "$@"
''
