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
    ./hosts/hetzy/hetzy-hostconfig.nix
    ./themes/trump/trump.nix
    ./users/zeroclaw
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
        home-manager switch --flake ~/repos/personal/dotfiles#zeroclaw-hetzy
      '';
      usage = "Runs home-manager switch for zeroclaw-hetzy.";
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
        sudo nixos-rebuild switch --flake ~/repos/personal/dotfiles#hetzy
      '';
      usage = "Runs nixos-rebuild switch for hetzy (requires sudo).";
    }
  ];
}
