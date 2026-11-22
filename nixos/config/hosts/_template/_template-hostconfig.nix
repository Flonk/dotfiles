{ ... }:
{
  config.t3os = {
    whoami.host = "__HOST__";
    host = {
      adminUser = "__USER__";
      motd.command = "printf '%b' '\\nWelcome to \\033[94mT3 OS\\033[0m.\\n'";
      ssh.authorizedKeys = [
        __SSH_KEYS__
      ];
    };

    module = { };
  };
}
