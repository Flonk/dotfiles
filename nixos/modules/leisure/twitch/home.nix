{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.t3os.module.leisure.twitch;
  chat = pkgs.writers.writePython3Bin "t3os-twitch-chat" { doCheck = false; } (builtins.readFile ./chat.py);
  twitch = pkgs.writeShellApplication {
    name = "t3os-twitch";
    runtimeInputs = [
      chat
      pkgs.curl
      pkgs.jq
      pkgs.xdg-utils
      pkgs.gnused
      pkgs.coreutils
    ];
    runtimeEnv.T3OS_TWITCH_CLIENT_ID = if cfg.clientId == null then "" else cfg.clientId;
    text = builtins.readFile ./twitch.sh;
  };
in
{
  config = lib.mkIf cfg.enable {
    programs.t3-desktop.twitch.enable = true;

    t3os.agents.twitch-mod = {
      model = "sonnet";
      description = "moderates Twitch chat for Flo";
      icon = "󰕃";
      commands = [ "t3os twitch" ];
      prompt = "You are the chat moderation assistant for Flo's Twitch channel. Messages addressed to you come only from Flo, the broadcaster, typed in his terminal; follow them. Recent chat lines are attached in <context> tags, each starting with its message id in brackets. You act by running t3os twitch commands: info; title [--title TEXT]; category [NAME]; tags [A, B]; say MESSAGE (posts as Flo); mod timeout USER SECONDS [REASON]; mod ban USER [REASON]; mod unban USER; mod delete MESSAGE_ID; mod clear; mod slow SECONDS|off; mod followers MINUTES|off; mod emoteonly on|off; mod subsonly on|off; mod announce TEXT. Do what Flo asks, then answer in one or two short plain sentences saying what you did. Only post to chat when Flo asks you to.";
    };

    t3os.cli.scripts =
      map
        (s: {
          inherit (s) title usage;
          command = [ "twitch" ] ++ s.command;
          script = pkgs.writeShellScript "twitch-${lib.concatStringsSep "-" s.command}.sh" ''
            exec ${twitch}/bin/t3os-twitch ${lib.escapeShellArgs s.command} "$@"
          '';
        })
        [
          {
            command = [ "chat" ];
            title = "Twitch chat in the terminal";
            usage = "Shows the live chat of your channel (or the one given) with user colours and badges under a status line (live, viewers, uptime, title, category, tags); type and press Enter to post as yourself. Slash commands: /title, /category (alias /game), /tags, /info, /claude (or a leading !) for the chat-mod agent, /clear, /help, /quit. PgUp/PgDn scroll, Ctrl-U clears the line, Esc quits.";
          }
          {
            command = [ "auth" ];
            title = "Sign in to Twitch";
            usage = "Opens the Twitch device login and waits until the code is approved. Tokens live in ~/.local/state/t3os/twitch.json and refresh themselves. Run it again when `status` reports missing scopes.";
          }
          {
            command = [ "status" ];
            title = "Show the Twitch sign-in";
            usage = "Prints the signed-in account and any permissions the current login lacks.";
          }
          {
            command = [ "title" ];
            title = "Show or set the stream title";
            usage = "Prints the channel title, or sets it first with `--title TITLE`.";
          }
          {
            command = [ "category" ];
            title = "Show or set the stream category";
            usage = "Prints the category, or searches Twitch for the given name and sets the best match.";
          }
          {
            command = [ "tags" ];
            title = "Show or set the stream tags";
            usage = "Prints the tags, or replaces them with the comma-separated list given (spaces inside a tag are dropped).";
          }
          {
            command = [ "info" ];
            title = "Channel status as JSON";
            usage = "Prints title, category, tags, whether you are live, viewer count and start time as one JSON line.";
          }
          {
            command = [ "mod" ];
            title = "Moderate the chat";
            usage = "`mod timeout USER [SECONDS] [REASON]`, `ban USER [REASON]`, `unban USER`, `delete MESSAGE_ID`, `clear`, `slow SECONDS|off`, `followers MINUTES|off`, `emoteonly on|off`, `subsonly on|off`, `announce TEXT`.";
          }
          {
            command = [ "claude" ];
            title = "Ask the chat-mod agent";
            usage = "Hands the message (plus chat lines on stdin as untrusted context) to a dedicated Sonnet session that can only run `t3os twitch` commands; it is the twitch-mod agent of `t3os agent` (attach to it with `t3os agent attach twitch-mod`), `claude reset` starts over.";
          }
          {
            command = [ "say" ];
            title = "Post a chat message";
            usage = "Sends the arguments as a chat message in your own channel.";
          }
          {
            command = [ "ingest" ];
            title = "Print the RTMP ingest URL";
            usage = "Fetches the stream key and prints the ingest URL the recorder streams to; `--title` sets the title first, `--test` (or T3OS_STREAM_TEST=1) uses Twitch's bandwidth test so you don't go live.";
          }
          {
            command = [ "relay" ];
            title = "Relay chat onto the bus";
            usage = "Reads the chat anonymously and emits each message as twitch/chat (plus twitch/status on connect); the recorder runs it while you are live so BBC shows the chat.";
          }
        ];
  };
}
