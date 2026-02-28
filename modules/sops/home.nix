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
      --border-label ' SKYNET SOPS ' \
      --header-label ' SKYNET SOPS ' \
      --header 'Select a secrets file to edit' \
      --preview='${pkgs.sops}/bin/sops -d $REPO_ROOT/{} | ${pkgs.bat}/bin/bat -p -l json --color=always' \
      --preview-window=right:60%:wrap \
    ) || exit 0

    exec ${pkgs.sops}/bin/sops "$REPO_ROOT/$selected"
  '';
in
{
  config = lib.mkIf config.skynet.module.sops.enable {
    skynet.cli.scripts = [
      {
        command = [ "sops" ];
        description = "Browse and edit encrypted secrets";
        script = "${sopsFzf}/bin/skynet-sops";
        preview = "echo 'Interactive sops secrets browser'";
      }
    ];
  };
}
