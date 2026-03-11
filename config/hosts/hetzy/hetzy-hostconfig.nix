{ ... }:
{
  config.skynet = {
    host = {
      adminUser = "zeroclaw";
      motd.command = "printf '%b' '\\033[38;5;208m╻ ╻┏━╸╺┳╸╺━┓╻ ╻\\n┣━┫┣╸  ┃ ┏━┛┗┳┛\\n╹ ╹┗━╸ ╹ ┗━╸ ╹\\033[94m    Built with NixOS and Skynet.\\033[0m\\n'";
      ssh.authorizedKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM0I6XBx5UT8ZnxEcfgdBZgy+1ub4QDrtLlgrpVIw//0 florian.schindler@andamp.io"
      ];
    };

    module = { };
  };
}
