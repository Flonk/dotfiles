{ ... }:
{
  config.skynet = {
    whoami.host = "hetzner";
    host = {
      adminUser = "claude";
      motd.command = "printf '%b' '\\nWelcome to \\033[94mSKYNET\\033[0m.\\n'";
      ssh.authorizedKeys = [
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHPzbr5UHfM2uIIbzd/bwhZVqTJhp+TjBTFPIZNSo5Re florian.schindler@andamp.io"
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCi36sZcMVvlSWxUrftMH5ECVfDOzVR3/sTHbZcai+/t6FaRM8OArBhhPMloMbPNYhRPx5s0/ELNpHvziYoNcyIfvIvfoL0Fjoa6Odc/o5Lf4UKRMyKzE0IRu29uEX4cH6MmnnsnYOM8+vqmhsf7unCLcbXmUcUOTM8DUti8BRS9+pjS0rf7dFSWNeGHNYkas8J22mSN9mua771cyQVyA45rc+y6GBymYmlBTUpaOd68hM6S4qzlUX2Ol1zI2VUmM3Nc8ZqJvvqTShboeyoqlASSulE2/INpvojQU0GFJqn9pYmz4HZDSOCFzYfDg3qCUKfkgDZDOIUQ5B5jNq10raI2Ap8yRb7L2FA9EZvZbx7ZSss1X5zIUhGD1KToG+0WtZd1txTRg4Kzyf1ZMxta/MyYSzWnxoyUdgXv5sNS5XzZz7Rq3ux1cipVyACRM67w307b8lvQOOEPqddj6y4Dint+vbTFQJkbTcpMTS/QXkcmKwg/vPoeXPmDWepmZKLZtp3PYZoVE+Ap+STTzXyfdhf7fzSIAwMjtkk1MsQ3IHlHM9OGQ/TDaNp89r6Vd22IpmUqHrj7UTZ7Mu2mQdwxJmBoCBfkSvydPTFmUj4xa9DHKQ6+Ur686T38zxacKliBB8F/11VRlWE3Jga3TY940Y2ybR8mxCojkFHFVnb0d1VLw== florian.schindler@andamp.io"
      ];
    };

    module = { };
  };
}
