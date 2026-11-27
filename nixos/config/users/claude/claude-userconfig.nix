{ ... }:
{
  config.t3os.whoami.user = "claude";

  config.t3os.agents.opus = {
    model = "opus";
    mode = "remote";
    description = "general agent on hetzner";
    cwd = "/home/claude/repos/personal/dotfiles";
    subagents = [
      "sonnet"
      "haiku"
    ];
  };

  config.t3os.module = {
    core = {
      direnv.enable = true;
      eventbus = {
        enable = true;
        ui = false;
        userBroker = true;
      };
      git.enable = true;
      sops.enable = true;
      zsh.enable = true;
    };
    ai = {
      claude-code.enable = true;
    };
    development = {
      gh.enable = true;
      obsidian.enable = true;
    };
    projects.andamp = {
      CEIFRS = true;
      crdpBackend = "xvfb";
      doubletunnel = true;
    };
  };
}
