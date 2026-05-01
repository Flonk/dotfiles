{
  pkgs,
  lib,
  inputs,
  sops,
  config,
  ...
}:
{
  imports = [
    ./types
    ./hosts/chonkler/chonkler-hostconfig.nix
    ./users/flo
  ];

  sops.age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
  sops.age.generateKey = true;

  skynet.cli.scripts = [
    {
      command = [
        "rebuild"
      ];
      title = "Rebuild home-manager config";
      script = pkgs.writeShellScript "rebuild.sh" ''
        set -euo pipefail
        echo "Rebuilding home-manager configuration..."
        home-manager switch --flake ~/repos/personal/dotfiles#flo-chonkler
      '';
      usage = "Runs home-manager switch for flo-chonkler.";
    }
    {
      command = [
        "system"
        "rebuild"
      ];
      title = "Rebuild NixOS system config";
      script = pkgs.writeShellScript "system-rebuild.sh" ''
        set -euo pipefail
        echo "Rebuilding NixOS system configuration..."
        sudo nixos-rebuild switch --fast --flake ~/repos/personal/dotfiles#chonkler
      '';
      usage = "Runs nixos-rebuild switch for chonkler (requires sudo).";
    }
  ];
}
