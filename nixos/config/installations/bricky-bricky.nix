{ ... }:
{
  imports = [
    ../../types
    ../hosts/bricky/bricky-hostconfig.nix
    ../users/bricky
  ];

  skynet.whoami.installation = "bricky-bricky";

}
