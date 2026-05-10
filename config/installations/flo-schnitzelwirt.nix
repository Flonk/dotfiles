{ ... }:
{
  imports = [
    ../../types
    ../hosts/schnitzelwirt/schnitzelwirt-hostconfig.nix
    ../users/flo
  ];

  skynet.whoami.installation = "flo-schnitzelwirt";

}
