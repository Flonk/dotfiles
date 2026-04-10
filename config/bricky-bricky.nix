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
    ./hosts/bricky/bricky-hostconfig.nix
    ./users/bricky
  ];

  skynet.cli.scripts = [
    {
      command = [
        "rebuild"
      ];
      title = "Rebuild home-manager config";
      script = pkgs.writeShellScript "rebuild.sh" ''
        set -euo pipefail
        echo "Rebuilding home-manager configuration..."
        home-manager switch --flake ~/repos/personal/dotfiles#bricky-bricky
      '';
      usage = "Runs home-manager switch for bricky-bricky.";
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
        sudo nixos-rebuild switch --flake ~/repos/personal/dotfiles#bricky
      '';
      usage = "Runs nixos-rebuild switch for bricky (requires sudo).";
    }
  ];
}
