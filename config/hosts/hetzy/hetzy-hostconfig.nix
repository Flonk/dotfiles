{ ... }:
{
  config.skynet = {
    host = {
      adminUser = "zeroclaw";
      ssh.authorizedKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM0I6XBx5UT8ZnxEcfgdBZgy+1ub4QDrtLlgrpVIw//0 florian.schindler@andamp.io"
      ];
    };

    module = { };
  };
}
