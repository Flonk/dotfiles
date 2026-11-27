{ lib, ... }:
let
  inherit (lib) mkOption types;
  models = types.enum [
    "haiku"
    "sonnet"
    "opus"
  ];
in
{
  options.t3os.agents = mkOption {
    default = { };
    description = "Claude agents, declared by modules or configs. Each publishes agent/<installation>-<name>/{meta,state,subagents,event} on the bus.";
    type = types.attrsOf (
      types.submodule (
        { name, ... }:
        {
          options = {
            model = mkOption { type = models; };
            description = mkOption {
              type = types.str;
              default = name;
            };
            mode = mkOption {
              type = types.enum [
                "remote"
                "headless"
              ];
              default = "headless";
              description = "remote: a long-running --remote-control service reachable from claude.ai. headless: no daemon, `t3os agent ask` resumes its session per message.";
            };
            cwd = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Working directory; defaults to ~/.local/state/t3os/agents/<name>.";
            };
            prompt = mkOption {
              type = types.str;
              default = "";
              description = "Appended to the system prompt.";
            };
            commands = mkOption {
              type = types.nullOr (types.listOf (types.strMatching "[a-z0-9][a-z0-9 -]*"));
              default = null;
              example = [ "t3os twitch" ];
              description = "Command prefixes the agent may run, enforced by a PreToolUse guard (Bash is its only tool). null means full access.";
            };
            subagents = mkOption {
              type = types.listOf models;
              default = [ ];
              description = "Models this agent may spawn subagents on (full-access agents only).";
            };
            icon = mkOption {
              type = types.str;
              default = lib.toUpper (builtins.substring 0 1 name);
              description = "Glyph shown for the agent in the bar.";
            };
          };
        }
      )
    );
  };
}
