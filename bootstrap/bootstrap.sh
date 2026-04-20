set -euo pipefail

host_key_pub="/etc/ssh/ssh_host_ed25519_key.pub"

if [[ ! -f "$host_key_pub" ]]; then
  echo "Host SSH key missing, generating with sudo ssh-keygen -A..."
  sudo ssh-keygen -A
fi

if [[ ! -f "$host_key_pub" ]]; then
  echo "Could not find $host_key_pub after ssh-keygen -A" >&2
  exit 1
fi

age_recipient="$(ssh-to-age < "$host_key_pub")"

echo ""
echo "Scan this QR and add the recipient to .sops.yaml on another machine:"
echo ""
printf '%s\n' "$age_recipient" | qrencode -t ansiutf8
echo ""
echo "Then on another admin machine with repo access:"
echo "  1) Add recipient to .sops.yaml"
echo "  2) Run: update-all-secrets"
echo "  3) Commit and push"
echo "  4) Pull here and run: bootstrap-part-2"
