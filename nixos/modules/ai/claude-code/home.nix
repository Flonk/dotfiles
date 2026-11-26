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
  rc = config.t3os.module.ai.claude-code.service;
  agentName = model: "${config.t3os.whoami.installation}-${model}";
  modelRank = [
    "haiku"
    "sonnet"
    "opus"
  ];
  spawnable =
    model:
    let
      rank = lib.lists.findFirstIndex (m: m == model) (-1) modelRank;
    in
    lib.take (lib.max 0 rank) modelRank;
  agentState = pkgs.writeShellScript "t3-agent-state" ''
    cat >/dev/null
    [ -n "''${T3_AGENT:-}" ] || exit 0
    dir="''${XDG_RUNTIME_DIR:-/tmp}/t3-agent/$T3_AGENT"
    mkdir -p "$dir"
    exec 9>"$dir/lock"
    ${pkgs.util-linux}/bin/flock 9
    subs=$(cat "$dir/subs" 2>/dev/null || echo 0)
    main=$(cat "$dir/main" 2>/dev/null || echo online)
    case "$1" in
      start) subs=0; main=online ;;
      prompt) main=thinking ;;
      idle) main=online ;;
      sub+) subs=$((subs + 1)) ;;
      sub-) subs=$((subs > 0 ? subs - 1 : 0)) ;;
      waiting) main=waiting ;;
      offline) subs=0; main=offline ;;
    esac
    echo "$subs" > "$dir/subs"
    echo "$main" > "$dir/main"
    state=$main
    [ "$main" != offline ] && [ "$subs" -gt 0 ] && state=heavy
    pub() { ${pkgs.mosquitto}/bin/mosquitto_pub -h 127.0.0.1 -q 1 "$@" 2>/dev/null; }
    pub -r -t "agent/$T3_AGENT/subagents" -m "$subs"
    pub -r -t "agent/$T3_AGENT/state" -m "$state"
    last=$(cat "$dir/last" 2>/dev/null || true)
    [ "$last" = "$state $subs" ] && exit 0
    echo "$state $subs" > "$dir/last"
    level=info attention=false
    case "$state" in
      online) what="is idle" ;;
      thinking) what="is working" ;;
      heavy) what="is running $subs subagent$([ "$subs" = 1 ] || echo s)" ;;
      waiting) what="needs your input"; level=warn; attention=true ;;
      offline) what="went offline"; level=warn ;;
      *) what="is $state" ;;
    esac
    body=$(${pkgs.jq}/bin/jq -nc \
      --arg ts "$(${pkgs.coreutils}/bin/date +%Y-%m-%dT%H:%M:%S.%3N%:z)" --arg src "claude/$T3_AGENT" --arg level "$level" \
      --argjson attention "$attention" --arg desc "$T3_AGENT $what." --arg state "$state" --argjson subs "$subs" \
      '{timestamp: $ts, source: $src, level: $level, attention: $attention, description: $desc, data: {state: $state, subagents: $subs}}')
    pub -t "agent/$T3_AGENT/event" -m "$body"
  '';
  subagentGuard = pkgs.writeShellScript "t3-subagent-guard" ''
    input=$(cat)
    jq() { ${pkgs.jq}/bin/jq "$@"; }
    deny() {
      jq -n --arg r "$1" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
      exit 0
    }
    me="''${T3_AGENT_MODEL:-?}"
    allow="''${T3_AGENT_ALLOW:-}"
    [ -n "$allow" ] || deny "$me may not spawn subagents. Do the work yourself."
    [ "$(jq -r .tool_name <<<"$input")" != Workflow ] || deny "Workflows are not allowed here. Spawn single agents with model set to one of: $allow."
    [ "$(jq -r '.tool_input.subagent_type // ""' <<<"$input")" != fork ] || deny "Forks run on your own model ($me). Spawn a fresh agent with model set to one of: $allow."
    model=$(jq -r '.tool_input.model // ""' <<<"$input")
    [ -n "$model" ] || deny "Set the model parameter explicitly to one of: $allow."
    case " $allow " in *" $model "*) exit 0 ;; esac
    deny "$me may only spawn subagents on: $allow (requested $model)."
  '';
  stateHook = state: [ { hooks = [ { type = "command"; command = "${agentState} ${state}"; } ]; } ];
  remoteSettings = pkgs.writeText "claude-remote-control-settings.json" (
    builtins.toJSON {
      idleCompaction = true;
      hooks = {
        SessionStart = stateHook "start";
        UserPromptSubmit = stateHook "prompt";
        Stop = stateHook "idle";
        SubagentStart = stateHook "sub+";
        SubagentStop = stateHook "sub-";
        SessionEnd = stateHook "offline";
        Notification = [
          {
            matcher = "permission_prompt|elicitation_dialog";
            hooks = [ { type = "command"; command = "${agentState} waiting"; } ];
          }
          {
            matcher = "idle_prompt";
            hooks = [ { type = "command"; command = "${agentState} idle"; } ];
          }
        ];
        PreToolUse = [
          {
            matcher = "Agent|Task|Workflow";
            hooks = [ { type = "command"; command = "${subagentGuard}"; } ];
          }
        ];
      };
    }
  );
  spawnRule =
    model:
    let
      allowed = spawnable model;
    in
    if allowed == [ ] then
      "You run on ${model}. You may not spawn subagents or workflows; do all work yourself."
    else
      "You run on ${model}. You may only spawn subagents with the model parameter set explicitly to ${lib.concatStringsSep " or " allowed}. Never fork, never omit the model, never start workflows.";
  remoteClaude = model: pkgs.writeShellScript "claude-remote-control-${model}-run" ''
    exec ${claudeScript}/bin/claude \
      --dangerously-skip-permissions \
      --model ${model} \
      --settings ${remoteSettings} \
      --append-system-prompt ${lib.escapeShellArg (spawnRule model)} \
      --remote-control ${agentName model}
  '';
  remoteControlScript = model: pkgs.writeShellScript "claude-remote-control-${model}" ''
    cd ${config.home.homeDirectory}/repos/personal/dotfiles
    exec ${pkgs.util-linux}/bin/script -q -c ${remoteClaude model} /dev/null
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
    (lib.mkIf config.t3os.module.ai.claude-code.service.enable {
      systemd.user.services = lib.listToAttrs (
        lib.imap0 (i: model: {
          name = "claude-remote-control-${model}";
          value = {
            Unit = {
              Description = "Claude Code Remote Control (${model})";
              After = [ "network-online.target" ];
              Wants = [ "network-online.target" ];
            };
            Service = {
              Type = "idle";
              Environment = [
                "T3_AGENT=${agentName model}"
                "T3_AGENT_MODEL=${model}"
                "T3_AGENT_ALLOW=${lib.concatStringsSep " " (spawnable model)}"
              ];
              ExecStartPre = "${pkgs.coreutils}/bin/sleep ${toString (i * 15)}";
              ExecStart = remoteControlScript model;
              ExecStopPost = "${agentState} offline";
              Restart = "on-failure";
              RestartSec = "5s";
            };
            Install.WantedBy = [ "default.target" ];
          };
        }) rc.models
      );
    })
  ];
}
