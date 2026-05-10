#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"
sops_yaml="$repo_root/.sops.yaml"
config_dir="$repo_root/config"
installations_dir="$config_dir/installations"
user_age_key_file="$HOME/.config/sops/age/keys.txt"
host_key_pub="/etc/ssh/ssh_host_ed25519_key.pub"

# ── Helpers ──────────────────────────────────────────────────────────────────

info()  { printf '\033[1;34m→\033[0m %s\n' "$*"; }
ok()    { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
err()   { printf '\033[1;31m✗\033[0m %s\n' "$*" >&2; }
ask()   { printf '\033[1;33m?\033[0m %s ' "$*"; }

confirm() {
  ask "$1 [y/N]:"
  read -r ans
  case "$ans" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

# ── Phase 0: Select or Create Installation ──────────────────────────────────

echo ""
echo "╔══════════════════════════════════════╗"
echo "║       skynet bootstrap (remote)      ║"
echo "╚══════════════════════════════════════╝"
echo ""

mapfile -t existing_installations < <(find "$installations_dir" -maxdepth 1 -name '*.nix' -printf '%f\n' | sed 's/\.nix$//' | sort)

echo "Use an existing installation or create a new one?"
echo "  1) Existing"
echo "  2) New"
ask "Choice [1/2]:"
read -r choice

if [[ "$choice" == "1" ]]; then
  if [[ "${#existing_installations[@]}" -eq 0 ]]; then
    err "No installations found in $installations_dir"
    exit 1
  fi
  installation="$(printf '%s\n' "${existing_installations[@]}" | fzf --prompt='Select installation > ' --height=40% --reverse)"
  [[ -z "$installation" ]] && { err "No selection made"; exit 1; }

  # Derive user and host from installation name
  user_name="${installation%%-*}"
  host_name="${installation#*-}"
else
  # Pick user
  mapfile -t users < <(find "$config_dir/users" -maxdepth 1 -mindepth 1 -type d -printf '%f\n' | sort)
  user_name="$(printf '%s\n' "${users[@]}" | fzf --prompt='Select user > ' --height=40% --reverse)"
  [[ -z "$user_name" ]] && { err "No selection made"; exit 1; }

  # Pick host
  mapfile -t hosts < <(find "$config_dir/hosts" -maxdepth 1 -mindepth 1 -type d -printf '%f\n' | sort)
  host_name="$(printf '%s\n' "${hosts[@]}" | fzf --prompt='Select host > ' --height=40% --reverse)"
  [[ -z "$host_name" ]] && { err "No selection made"; exit 1; }

  # Installation name
  ask "Installation name (e.g. ${user_name}-${host_name}):"
  read -r installation
  [[ -z "$installation" ]] && { err "Name cannot be empty"; exit 1; }

  # Generate installation file
  cat > "$installations_dir/$installation.nix" <<NIXEOF
{ ... }:
{
  imports = [
    ../../types
    ../hosts/${host_name}/${host_name}-hostconfig.nix
    ../users/${user_name}
  ];

  skynet.whoami.installation = "${installation}";

}
NIXEOF
  ok "Created $installations_dir/$installation.nix"
fi

info "Installation: $installation (user: $user_name, host: $host_name)"

# ── Phase 1: Key Setup ──────────────────────────────────────────────────────

# Check for duplicates in .sops.yaml
if grep -q "&user_${installation}" "$sops_yaml" 2>/dev/null; then
  err "Key '&user_${installation}' already exists in .sops.yaml"
  exit 1
fi
if grep -q "&host_${installation}" "$sops_yaml" 2>/dev/null; then
  err "Key '&host_${installation}' already exists in .sops.yaml"
  exit 1
fi

# Ensure SSH host key
if [[ ! -f "$host_key_pub" ]]; then
  info "Host SSH key missing, generating..."
  sudo ssh-keygen -A
fi
[[ -f "$host_key_pub" ]] || { err "Could not find $host_key_pub"; exit 1; }
ok "SSH host key exists"

# Generate age user key
if [[ ! -f "$user_age_key_file" ]]; then
  info "Generating age user key at $user_age_key_file..."
  mkdir -p "$(dirname "$user_age_key_file")"
  nix-shell -p age --run "age-keygen -o '$user_age_key_file'" 2>/dev/null
fi
ok "Age user key exists"

# Derive age recipients
host_age_recipient="$(nix-shell -p ssh-to-age --run "ssh-to-age < '$host_key_pub'" 2>/dev/null)"
user_age_recipient="$(nix-shell -p age --run "age-keygen -y '$user_age_key_file'" 2>/dev/null)"

echo ""
info "Host age recipient (&host_${installation}):"
echo "  $host_age_recipient"
echo ""
info "User age recipient (&user_${installation}):"
echo "  $user_age_recipient"

# Add to .sops.yaml keys section ONLY (before creation_rules:)
info "Adding keys to .sops.yaml (keys section only)..."
sed -i "/^creation_rules:/i\\  - \&user_${installation} ${user_age_recipient}" "$sops_yaml"
sed -i "/^creation_rules:/i\\  - \&host_${installation} ${host_age_recipient}" "$sops_yaml"
ok "Updated .sops.yaml keys section"

echo ""
info "Current .sops.yaml:"
cat "$sops_yaml"

# ── Phase 2: Wait for manual creation_rules update ──────────────────────────

echo ""
echo "┌──────────────────────────────────────────────────────────────────┐"
echo "│  Now you need to:                                               │"
echo "│    1. Add *user_${installation} and *host_${installation} to creation_rules  │"
echo "│    2. Update flake.nix if this is a new installation            │"
echo "│  Then on your dev laptop:                                       │"
echo "│    3. git pull                                                  │"
echo "│    4. ./bootstrap/update-all-secrets.sh                         │"
echo "│    5. git add -A && git commit && git push                      │"
echo "└──────────────────────────────────────────────────────────────────┘"
echo ""
ask "Type 'done' when ready:"
while true; do
  read -r ans
  [[ "$ans" == "done" ]] && break
  ask "Type 'done' when ready:"
done

# ── Phase 3: Pull and Build ─────────────────────────────────────────────────

info "Pulling latest changes..."
cd "$repo_root"
git pull
ok "Pulled"

info "Rebuilding NixOS system: #$host_name"
sudo nixos-rebuild switch --flake "$repo_root#$host_name"
ok "NixOS rebuild complete"

info "Rebuilding Home Manager: #$installation"
if command -v home-manager &>/dev/null; then
  home-manager switch --flake "$repo_root#$installation"
else
  info "home-manager not on PATH, using nix run..."
  nix run home-manager/master -- switch --flake "$repo_root#$installation"
fi
ok "Home Manager rebuild complete"

echo ""
ok "Bootstrap complete! Welcome to skynet."
