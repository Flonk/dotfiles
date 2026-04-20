set -euo pipefail
shopt -s nullglob

mapfile -t secret_files < <(
  find . -type f -path "*/secrets/*" \
    | grep -E '\.(yaml|json|env|ini|ovpn|crt)$' \
    | sort
)

if [[ "${#secret_files[@]}" -eq 0 ]]; then
  echo "No matching secret files found."
  exit 1
fi

for file in "${secret_files[@]}"; do
  echo "Updating keys for $file"
  sops updatekeys "$file"
done
