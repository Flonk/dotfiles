{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ../../../types
    ../common.nix
    ./bricky-hostconfig.nix
  ];

  wsl.enable = true;
  wsl.defaultUser = "bricky";

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  users.users.bricky = {
    isNormalUser = true;
    description = "bricky";
    extraGroups = [
      "wheel"
      "docker"
    ];
  };

  virtualisation.docker.enable = false;
  virtualisation.docker.enableOnBoot = false;

  environment.variables.EDITOR = "micro";

  system.stateVersion = "25.05";
}
