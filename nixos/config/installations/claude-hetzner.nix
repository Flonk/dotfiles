{ ... }:
{
  imports = [
    ../../types
    ../hosts/hetzner/hetzner-hostconfig.nix
    ../users/claude
  ];

  t3os.whoami.installation = "claude-hetzner";

  dconf.enable = false;

}
