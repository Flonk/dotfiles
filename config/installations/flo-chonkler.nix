{ ... }:
{
  imports = [
    ../../types
    ../hosts/chonkler/chonkler-hostconfig.nix
    ../users/flo
  ];

  skynet.whoami.installation = "flo-chonkler";

}
