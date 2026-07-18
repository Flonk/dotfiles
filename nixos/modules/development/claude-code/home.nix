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
  claudeChromeScript = pkgs.writeShellScriptBin "claude-chrome" ''
    exec ${pkgs.google-chrome}/bin/google-chrome-stable --class=claude-chrome "$@"
  '';
  claudeRemoteControlScript = pkgs.writeShellScriptBin "claude-remote-control-start" ''
    cd ${config.home.homeDirectory}/repos/personal/dotfiles
    exec ${pkgs.util-linux}/bin/script -q -c '${claudeScript}/bin/claude --dangerously-skip-permissions --remote-control ${config.skynet.whoami.installation}' /dev/null
  '';
in
{
  config = lib.mkMerge [
    (lib.mkIf config.skynet.module.development.claude-code.enable {
      home.packages = [
        pkgs.gh
        claudeScript
        claudeChromeScript
      ];

      wayland.windowManager.hyprland.settings.window_rule =
        lib.optionals config.programs.gloxwald.hyprland.enable [
          { match.class = "^claude-chrome$"; workspace = "10 silent"; }
          { match.class = "^claude-chrome$"; suppress_event = "activatefocus"; }
        ];
    })
    (lib.mkIf config.skynet.module.development.claude-code.service.enable {
      systemd.user.services.claude-remote-control = {
        Unit = {
          Description = "Claude Code Remote Control";
          After = [ "network-online.target" ];
          Wants = [ "network-online.target" ];
        };
        Service = {
          Type = "idle";
          ExecStart = "${claudeRemoteControlScript}/bin/claude-remote-control-start";
          Restart = "on-failure";
          RestartSec = "5s";
        };
        Install = {
          WantedBy = [ "default.target" ];
        };
      };
    })
  ];
}
