{ ... }:
{
  config.skynet = {
    whoami.host = "__HOST__";
    host = {
      adminUser = "__USER__";
      motd.command = "printf '%b' '\\nWelcome to \\033[94mSKYNET\\033[0m.\\n'";
      ssh.authorizedKeys = [
        __SSH_KEYS__
      ];
    };

    module = { };
  };
}
