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
  autoXephyrScript = pkgs.writeShellScriptBin "auto-xephyr" ''
    ${pkgs.xorg-server}/bin/Xephyr :9 -title auto-xephyr -no-host-grab -resizeable "$@" &
    pid=$!
    trap 'kill $pid 2>/dev/null' EXIT INT TERM
    until DISPLAY=:9 ${pkgs.setxkbmap}/bin/setxkbmap ${config.wayland.windowManager.hyprland.settings.config.input.kb_layout or "us"} 2>/dev/null; do
      kill -0 $pid 2>/dev/null || exit 1
      sleep 0.1
    done
    wait $pid
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
        autoXephyrScript
      ];

      wayland.windowManager.hyprland.settings.window_rule =
        lib.optionals config.programs.gloxwald.hyprland.enable [
          { match.class = "^claude-chrome$"; workspace = "10 silent"; }
          { match.class = "^claude-chrome$"; suppress_event = "activatefocus"; }
          { match = { class = "^Xephyr$"; title = "^auto-xephyr$"; }; workspace = "9 silent"; }
          { match = { class = "^Xephyr$"; title = "^auto-xephyr$"; }; suppress_event = "activatefocus"; }
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
