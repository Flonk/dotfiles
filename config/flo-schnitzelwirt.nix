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

  programs.zsh.shellAliases.nr = "(pkill walker || echo 0) && home-manager switch --flake ~/repos/personal/dotfiles#flo-schnitzelwirt";
  programs.zsh.shellAliases.nrsys = "sudo nixos-rebuild switch --flake ~/repos/personal/dotfiles#schnitzelwirt";

  skynet.cli.scripts = [
    {
      command = [
        "rebuild"
      ];
      title = "Rebuild home-manager config";
      script = pkgs.writeShellScript "rebuild.sh" ''
        set -euo pipefail
        echo "Rebuilding home-manager configuration..."
        (pkill walker || echo 0) && home-manager switch --flake ~/repos/personal/dotfiles#flo-schnitzelwirt
      '';
      usage = "Kills walker and runs home-manager switch for flo-schnitzelwirt.";
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
