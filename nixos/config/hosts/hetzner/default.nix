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

  services.openssh = {
    ports = [
      22
      443
    ];
    openFirewall = false;
  };

  networking.firewall.allowedTCPPorts = [ 22 ];

  environment.systemPackages = [
    (pkgs.writeShellScriptBin "tuersteher" ''
      set -euo pipefail
      IPT="${pkgs.iptables}/bin/iptables"
      RULE=(nixos-fw -p tcp --dport 443 -m comment --comment tuersteher -j nixos-fw-accept)
      sudo systemctl stop tuersteher-close.timer 2>/dev/null || true
      sudo $IPT -D "''${RULE[@]}" 2>/dev/null || true
      if [ "''${1:-open}" = "close" ]; then
        echo "ssh on 443 closed"
        exit 0
      fi
      sudo $IPT -I "''${RULE[@]}"
      sudo ${pkgs.systemd}/bin/systemd-run --quiet --collect --unit tuersteher-close --on-active=120 $IPT -D "''${RULE[@]}"
      echo "ssh on 443 open for 2 minutes"
    '')
  ];

  security.sudo.extraRules = [
    {
      users = [ "claude" ];
      commands = [ { command = "ALL"; options = [ "NOPASSWD" ]; } ];
    }
  ];
}
