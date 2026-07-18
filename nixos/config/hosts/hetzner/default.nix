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
    ./hetzner-hardware.nix
    ./hetzner-hostconfig.nix
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  system.stateVersion = "24.11";

  programs.nix-ld.enable = true;

  security.sudo.extraRules = [
    {
      users = [ "claude" ];
      commands = [ { command = "ALL"; options = [ "NOPASSWD" ]; } ];
    }
  ];
}
