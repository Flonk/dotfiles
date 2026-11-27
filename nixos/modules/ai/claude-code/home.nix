{
  pkgs,
  config,
  lib,
  ...
}:
let
  claudeScript = import ./package.nix { inherit pkgs; };
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
in
{
  config = lib.mkMerge [
    (lib.mkIf config.t3os.module.ai.claude-code.enable {
      home.file.".claude/CLAUDE.md".source = ../../../../CLAUDE.global.md;

      home.packages = [
        claudeScript
        claudeChromeScript
        autoXephyrScript
      ];

      wayland.windowManager.hyprland.settings.window_rule =
        lib.optionals config.programs.t3-desktop.hyprland.enable [
          { match.class = "^claude-chrome$"; workspace = "10 silent"; }
          { match.class = "^claude-chrome$"; suppress_event = "activatefocus"; }
          { match = { class = "^Xephyr$"; title = "^auto-xephyr$"; }; workspace = "9 silent"; }
          { match = { class = "^Xephyr$"; title = "^auto-xephyr$"; }; suppress_event = "activatefocus"; }
        ];
    })
  ];
}
