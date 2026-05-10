{
  pkgs,
  config,
  lib,
  ...
}:
let
  claudeScript = pkgs.writeShellScriptBin "claude" ''
    export PATH="${pkgs.nodejs}/bin:$PATH"
    exec ${pkgs.nodejs}/bin/npx --yes @anthropic-ai/claude-code "$@"
  '';
  claudeRemoteControlScript = pkgs.writeShellScriptBin "claude-remote-control-start" ''
    cd ${config.home.homeDirectory}/repos/personal/dotfiles/claude
    exec ${pkgs.util-linux}/bin/script -q -c '${claudeScript}/bin/claude --dangerously-skip-permissions --remote-control ${config.skynet.whoami.installation}' /dev/null
  '';
in
{
  config = lib.mkMerge [
    (lib.mkIf config.skynet.module.development.claude-code.enable {
      home.packages = [
        pkgs.gh
        claudeScript
      ];
    })
    (lib.mkIf config.skynet.module.development.claude-code.service.enable {
      systemd.user.services.claude-remote-control = {
        Unit = {
          Description = "Claude Code Remote Control";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Service = {
          Type = "simple";
          ExecStart = "${claudeRemoteControlScript}/bin/claude-remote-control-start";
          Restart = "on-failure";
          RestartSec = "5s";
        };
        Install = {
          WantedBy = [ "graphical-session.target" ];
        };
      };
    })
  ];
}
