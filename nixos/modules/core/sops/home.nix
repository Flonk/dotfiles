{
  config,
  lib,
  pkgs,
  ...
}:

let
  fzfThemeArgs = config.skynet.cli.fzfThemeArgs;

  sopsFzf = pkgs.writeShellScriptBin "skynet-sops" ''
    set -euo pipefail

    export REPO_ROOT="$(${pkgs.git}/bin/git rev-parse --show-toplevel 2>/dev/null || echo "$HOME/repos/personal/dotfiles")"
    export SOPS_AGE_KEY_FILE="''${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"

    # Find all secrets JSON files in the repo
    files=$(${pkgs.findutils}/bin/find "$REPO_ROOT" -path '*/secrets/*.json' -type f | ${pkgs.coreutils}/bin/sort)

    if [[ -z "$files" ]]; then
      echo "No secrets JSON files found."
      exit 0
    fi

    # Make paths relative to repo root for display
    entries=$(echo "$files" | while IFS= read -r f; do
      echo "''${f#$REPO_ROOT/}"
    done)

    selected=$(echo "$entries" | ${pkgs.fzf}/bin/fzf \
      ${fzfThemeArgs} \
      --border-label ' SKYNET SECRETS ' \
      --header-label ' SKYNET SECRETS ' \
      --header 'Select a secrets file to edit' \
      --preview='${pkgs.sops}/bin/sops -d $REPO_ROOT/{} | ${pkgs.bat}/bin/bat -p -l json --color=always' \
      --preview-window=right:60%:wrap \
    ) || exit 0

    exec ${pkgs.sops}/bin/sops "$REPO_ROOT/$selected"
  '';

  sopsRegenerate = pkgs.writeShellScript "skynet-sops-regenerate.sh" ''
    set -euo pipefail
    shopt -s nullglob

    REPO_ROOT="$(${pkgs.git}/bin/git rev-parse --show-toplevel 2>/dev/null || echo "$HOME/repos/personal/dotfiles")"
    export SOPS_AGE_KEY_FILE="''${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"

    mapfile -t files < <(
      ${pkgs.findutils}/bin/find "$REPO_ROOT" -type f -path '*/secrets/*' \
        | ${pkgs.gnugrep}/bin/grep -E '\.(yaml|json|env|ini|ovpn|crt)$' \
        | ${pkgs.coreutils}/bin/sort
    )

    if [[ "''${#files[@]}" -eq 0 ]]; then
      echo "No matching secret files found."
      exit 0
    fi

    for file in "''${files[@]}"; do
      echo "Updating keys for ''${file#$REPO_ROOT/}"
      ${pkgs.sops}/bin/sops updatekeys -y "$file"
    done
  '';
in
{
  config = lib.mkIf config.skynet.module.core.sops.enable {
    sops.age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";

    skynet.cli.scripts = [
      {
        command = [ "secrets" ];
        title = "Browse and edit encrypted secrets";
        script = "${sopsFzf}/bin/skynet-sops";
        usage = "Browse and edit all sops-nix secrets in the dotfiles repository.";
      }
      {
        command = [ "secrets" "regenerate" ];
        title = "Re-encrypt all secrets with current .sops.yaml recipients";
        script = sopsRegenerate;
        usage = "Runs `sops updatekeys` on every secret file in the repo so new recipients in .sops.yaml take effect.";
      }
    ];
  };
}
