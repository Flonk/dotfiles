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
    ./hosts/schnitzelwirt/schnitzelwirt-hostconfig.nix
    ./themes/trump/trump.nix
    ./users/flo
  ];

  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
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
        home-manager switch --flake ~/repos/personal/dotfiles#flo-schnitzelwirt
      '';
      usage = "Runs home-manager switch for flo-schnitzelwirt.";
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
        sudo nixos-rebuild switch --flake ~/repos/personal/dotfiles#schnitzelwirt
      '';
      usage = "Runs nixos-rebuild switch for schnitzelwirt (requires sudo).";
    }
  ];
}
