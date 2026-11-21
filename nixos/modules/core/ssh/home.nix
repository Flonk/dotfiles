{
  config,
  lib,
  pkgs,
  ...
}:

let
  pickHost = pkgs.writeShellScript "skynet-ssh-pick.sh" ''
    set -euo pipefail

    REGISTRY="$HOME/repos/personal/dotfiles/nixos/.registry.json"

    if [[ ! -f "$REGISTRY" ]]; then
      echo "Registry not found: $REGISTRY" >&2
      exit 1
    fi

    entries=$(${pkgs.jq}/bin/jq -r '
      to_entries[]
      | select(.value.user? and .value.ip?)
      | [.key, .value.user, .value.ip, (.value.knock // false | tostring)]
      | join("\t")
    ' "$REGISTRY")

    if [[ -z "$entries" ]]; then
      echo "No SSH hosts found in registry." >&2
      exit 1
    fi

    echo "$entries" | ${pkgs.fzf}/bin/fzf \
      --height=8 --layout=reverse \
      --delimiter=$'\t' --with-nth=1 \
      --query="''${1:-}" --select-1 --exit-0
  '';

  sops = config.skynet.module.core.sops.enable;

  knock = pkgs.writeShellScript "skynet-ssh-knock.sh" (
    if sops then
      ''
        set -euo pipefail
        rc=$(mktemp)
        trap 'rm -f "$rc"' EXIT
        printf '[default]\n\n[target]\nSPA_SERVER %s\nACCESS tcp/22\nALLOW_IP source\nUSE_HMAC Y\nKEY_BASE64 %s\nHMAC_KEY_BASE64 %s\n' \
          "$1" "$(cat ${config.sops.secrets.fwknop-key.path})" "$(cat ${config.sops.secrets.fwknop-hmac.path})" > "$rc"
        echo "Knocking on $1..."
        ${pkgs.fwknop}/bin/fwknop --rc-file "$rc" -n target
        sleep 1
      ''
    else
      ''
        echo "fwknop keys need core.sops enabled" >&2
        exit 1
      ''
  );

  sshScript = pkgs.writeShellScript "skynet-ssh.sh" ''
    set -euo pipefail

    selected=$(${pickHost} "''${1:-}") || { [[ $# -eq 0 ]] && exit 0 || { echo "No host matched '$1'" >&2; exit 1; }; }

    user=$(echo "$selected" | cut -f2)
    ip=$(echo "$selected" | cut -f3)
    host=$(echo "$selected" | cut -f1)

    [[ $(echo "$selected" | cut -f4) == true ]] && ${knock} "$ip"

    echo "Connecting to $host ($user@$ip)..."
    exec ${pkgs.openssh}/bin/ssh "$user@$ip"
  '';

  rebuildScript = pkgs.writeShellScript "skynet-ssh-rebuild.sh" ''
    set -euo pipefail

    DOTFILES="$HOME/repos/personal/dotfiles"

    selected=$(${pickHost} "''${1:-}") || { [[ $# -eq 0 ]] && exit 0 || { echo "No host matched '$1'" >&2; exit 1; }; }

    installation=$(echo "$selected" | cut -f1)
    user=$(echo "$selected" | cut -f2)
    ip=$(echo "$selected" | cut -f3)

    echo "→ Committing local changes..."
    cd "$DOTFILES"
    ${pkgs.git}/bin/git add -A
    if ! ${pkgs.git}/bin/git diff --cached --quiet; then
      ${pkgs.git}/bin/git commit -m "--wip-- [skip ci]"
    fi
    ${pkgs.git}/bin/git push

    [[ $(echo "$selected" | cut -f4) == true ]] && ${knock} "$ip"

    echo "→ Rebuilding $installation on $ip..."
    exec ${pkgs.openssh}/bin/ssh -t "$user@$ip" \
      "cd ~/repos/personal/dotfiles && git pull && home-manager switch --flake ./nixos#$installation"
  '';
in
{
  config = lib.mkIf config.skynet.module.core.ssh.enable {
    skynet.module.core.ssh.knockScript = knock;

    sops.secrets = lib.mkIf sops {
      fwknop-key.sopsFile = ./secrets/fwknop.json;
      fwknop-hmac.sopsFile = ./secrets/fwknop.json;
    };

    skynet.cli.scripts = [
      {
        command = [ "ssh" ];
        title = "SSH into a registered host";
        script = sshScript;
        usage = "Pick a host from .registry.json and SSH into it. Pass a query to fuzzy-match and connect directly (e.g. `skynet ssh cl` connects to claude-hetzner).";
      }
      {
        command = [ "deploy" ];
        title = "Push dotfiles and rebuild a remote host";
        script = rebuildScript;
        usage = "Commits local dotfiles changes (--wip--), pushes, SSHes to the host, pulls, and runs home-manager switch. Pass a query to skip the picker (e.g. `skynet deploy cl`).";
      }
    ];
  };
}
