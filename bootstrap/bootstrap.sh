set -euo pipefail

host_key_pub="/etc/ssh/ssh_host_ed25519_key.pub"
user_age_key_file="$HOME/.config/sops/age/keys.txt"

if [[ ! -f "$host_key_pub" ]]; then
  echo "Host SSH key missing, generating with sudo ssh-keygen -A..."
  sudo ssh-keygen -A
fi

if [[ ! -f "$host_key_pub" ]]; then
  echo "Could not find $host_key_pub after ssh-keygen -A" >&2
  exit 1
fi

if [[ ! -f "$user_age_key_file" ]]; then
  echo "User age key missing, generating at $user_age_key_file..."
  mkdir -p "$(dirname "$user_age_key_file")"
  age-keygen -o "$user_age_key_file" >/dev/null
fi

host_age_recipient="$(ssh-to-age < "$host_key_pub")"
user_age_recipient="$(age-keygen -y "$user_age_key_file")"

echo ""
echo "Host recipient (from /etc/ssh/ssh_host_ed25519_key.pub):"
echo "$host_age_recipient"
echo ""
printf '%s\n' "$host_age_recipient" | qrencode -t ansiutf8
echo ""
echo "User recipient (from $user_age_key_file):"
echo "$user_age_recipient"
echo ""
printf '%s\n' "$user_age_recipient" | qrencode -t ansiutf8
echo ""
echo "Then on another admin machine with repo access:"
echo "  1) Add host + user recipients to .sops.yaml"
echo "  2) Run: update-all-secrets"
echo "  3) Commit and push"
echo "  4) Pull here and run: bootstrap-part-2"
