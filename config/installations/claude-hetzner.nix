{ ... }:
{
  imports = [
    ../../types
    ../hosts/hetzner/hetzner-hostconfig.nix
    ../users/claude
  ];

  skynet.whoami.installation = "claude-hetzner";

}
