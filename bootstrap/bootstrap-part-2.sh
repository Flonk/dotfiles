set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
config_dir="$repo_root/config"

if [[ ! -d "$config_dir" ]]; then
  echo "Could not find config directory at $config_dir" >&2
  exit 1
fi

mapfile -t config_files < <(find "$config_dir" -maxdepth 1 -type f -name '*.nix' -printf '%f\n' | sort)

if [[ "${#config_files[@]}" -eq 0 ]]; then
  echo "No top-level config/*.nix files found." >&2
  exit 1
fi

selected_file="$(printf '%s\n' "${config_files[@]}" | fzf --prompt='Select home config > ' --height=40% --reverse)"
if [[ -z "$selected_file" ]]; then
  echo "No selection made."
  exit 1
fi

selected_config="${selected_file%.nix}"
host="${selected_config#*-}"

if [[ "$host" == "$selected_config" || -z "$host" ]]; then
  echo "Could not derive host from config '$selected_config' (expected user-host format)." >&2
  exit 1
fi

host_hardware_path="$repo_root/config/hosts/$host/$host-hardware.nix"

echo "Selected home config: $selected_config"
echo "Derived host config: $host"
printf "Generate hardware config and write to %s? [y/N]: " "$host_hardware_path"
read -r do_hardware

case "$do_hardware" in
  y|Y|yes|YES)
    mkdir -p "$(dirname "$host_hardware_path")"
    nixos-generate-config --show-hardware-config > "$host_hardware_path"
    echo "Wrote hardware config to $host_hardware_path"
    ;;
  *)
    echo "Skipping hardware config generation."
    ;;
esac

echo "Rebuilding NixOS system: #$host"
sudo nixos-rebuild switch --flake "$repo_root#$host"

echo "Rebuilding Home Manager: #$selected_config"
home-manager switch --flake "$repo_root#$selected_config"
