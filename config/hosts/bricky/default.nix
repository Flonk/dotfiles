{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ../../types
    ../common.nix
    ./bricky-hostconfig.nix
  ];

  networking.hostName = "bricky";

  wsl.enable = true;
  wsl.defaultUser = "bricky";

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  nixpkgs.config.allowUnfree = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  users.users.bricky = {
    isNormalUser = true;
    description = "bricky";
    extraGroups = [
      "wheel"
      "docker"
    ];
  };

  virtualisation.docker.enable = true;
  virtualisation.docker.enableOnBoot = false;

  environment.variables.EDITOR = "micro";

  system.stateVersion = "25.05";
}
