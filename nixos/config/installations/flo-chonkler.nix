{ ... }:
{
  imports = [
    ../../types
    ../hosts/chonkler/chonkler-hostconfig.nix
    ../users/flo
  ];

  t3os.whoami.installation = "flo-chonkler";

}
