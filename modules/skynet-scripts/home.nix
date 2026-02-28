{
  config,
  lib,
  pkgs,
  ...
}:

let
  scripts = config.skynet.cli.scripts;
  hasScripts = scripts != [ ];
  hasTs = builtins.any (s: lib.hasSuffix ".ts" (toString s.script)) scripts;

  # Theme colors
  c = config.theme.color;

  # Build node_modules from package.json (only needed if TS scripts exist)
  nodeModules = pkgs.buildNpmPackage {
    pname = "skynet-scripts-deps";
    version = "1.0.0";
    src = ./.;
    npmDepsHash = "sha256-aINlEcFIuu0QW+hgsZF2gyj3EuK1+j5Am5IqZm7zjZg=";
    dontNpmBuild = true;
    installPhase = ''
      mkdir -p $out
      cp -r node_modules $out/
    '';
  };

  # Build the scripts directory with all registered scripts
  scriptsDir = pkgs.runCommand "skynet-scripts" { } ''
    mkdir -p $out

    ${lib.optionalString hasTs ''
      cp ${./package.json} $out/package.json
      cp -r ${nodeModules}/node_modules $out/
    ''}

    ${lib.concatMapStringsSep "\n" (
      s:
      let
        dir = lib.concatStringsSep "/" (lib.init s.command);
        filename =
          lib.last s.command
          + (lib.optionalString (lib.hasSuffix ".ts" (toString s.script)) ".ts")
          + (lib.optionalString (lib.hasSuffix ".sh" (toString s.script)) ".sh");
      in
      ''
        mkdir -p $out/${dir}
        cp ${s.script} $out/${dir}/${filename}
        ${lib.optionalString (lib.hasSuffix ".sh" (toString s.script)) "chmod +x $out/${dir}/${filename}"}
      ''
    ) scripts}
  '';

  # Command string for each script, e.g. "fingerprint enroll"
  cmdStr = s: lib.concatStringsSep " " s.command;

  # Relative path in scripts dir, e.g. "fingerprint/enroll.ts"
  scriptRelPath =
    s:
    let
      dir = lib.concatStringsSep "/" (lib.init s.command);
      ext =
        if lib.hasSuffix ".ts" (toString s.script) then
          ".ts"
        else if lib.hasSuffix ".sh" (toString s.script) then
          ".sh"
        else
          "";
      filename = lib.last s.command + ext;
    in
    "${dir}/${filename}";

  # Generate the dispatch case for a single script
  mkDispatchCase =
    s:
    let
      cmd = cmdStr s;
      nArgs = builtins.length s.command;
      relPath = scriptRelPath s;
      isTs = lib.hasSuffix ".ts" relPath;
    in
    ''
      "${cmd}")
        shift ${toString nArgs}
        ${
          if isTs then
            ''exec "$SCRIPTS_DIR/node_modules/.bin/tsx" "$SCRIPTS_DIR/${relPath}" "$@"''
          else
            ''exec "$SCRIPTS_DIR/${relPath}" "$@"''
        }
        ;;'';

  # Generate fzf entries: "command path | description"
  mkFzfEntry = s: "${cmdStr s}\t${s.description}";

  # Build the preview dispatch for fzf
  mkPreviewCase =
    s:
    let
      cmd = cmdStr s;
    in
    if s.preview != "" then ''"${cmd}") ${s.preview} ;;'' else ''"${cmd}") echo "${s.description}" ;;'';

  # The main skynet CLI script
  skynetBin = pkgs.writeShellScriptBin "skynet" ''
    set -euo pipefail

    SCRIPTS_DIR="$HOME/.skynet/scripts"

    # --- Dispatch subcommands ---
    dispatch() {
      local args=""
      for arg in "$@"; do
        args="''${args:+$args }$arg"
      done

      case "$args" in
        ${lib.concatMapStringsSep "\n        " mkDispatchCase scripts}
        *)
          return 1
          ;;
      esac
    }

    # --- Help ---
    show_help() {
      echo "skynet - module script runner"
      echo ""
      echo "Usage: skynet <command> [args...]"
      echo "       skynet              Interactive script picker (fzf)"
      echo "       skynet --help       Show this help"
      echo ""
      echo "Available commands:"
      ${lib.concatMapStringsSep "\n      " (
        s: ''echo "  ${lib.fixedWidthString 30 " " (cmdStr s)}${s.description}"''
      ) scripts}
    }

    # --- fzf preview script (called internally) ---
    _skynet_preview() {
      local cmd="$1"
      case "$cmd" in
        ${lib.concatMapStringsSep "\n        " mkPreviewCase scripts}
        *) echo "No preview available" ;;
      esac
    }

    # --- Interactive fzf picker ---
    interactive() {
      local entries
      entries=$(printf '%b\n' \
        ${lib.concatMapStringsSep " \\\n        " (s: ''"${cmdStr s}\t${s.description}"'') scripts}
      )

      local selected
      selected=$(echo "$entries" | ${pkgs.fzf}/bin/fzf \
        --style full \
        --border --padding 1,2 \
        --border-label ' SKYNET TUI ' \
        --input-label ' Search ' \
        --header-label ' SKYNET ' \
        --header 'Select a script to run' \
        --delimiter=$'\t' \
        --with-nth=1 \
        --preview='skynet _preview {1}' \
        --preview-window=right:50%:wrap \
        --bind 'result:transform-list-label:
          if [[ -z $FZF_QUERY ]]; then
            echo " $FZF_MATCH_COUNT scripts "
          else
            echo " $FZF_MATCH_COUNT matches for [$FZF_QUERY] "
          fi
          ' \
        --bind 'focus:transform-preview-label:[[ -n {1} ]] && printf " %s " {1}' \
        --bind 'focus:+transform-header:{2}' \
        --color 'border:${c.wm800},label:${c.wm800}' \
        --color 'preview-border:${c.app500},preview-label:${c.app800}' \
        --color 'list-border:${c.app400},list-label:${c.app600}' \
        --color 'input-border:${c.wm800},input-label:${c.wm800}' \
        --color 'header-border:${c.app500},header-label:${c.app800}' \
      ) || exit 0

      local cmd
      cmd=$(echo "$selected" | cut -f1)
      # shellcheck disable=SC2086
      dispatch $cmd
    }

    # --- Main ---
    if [[ $# -eq 0 ]]; then
      interactive
    elif [[ "$1" == "--help" || "$1" == "-h" ]]; then
      show_help
    elif [[ "$1" == "_preview" ]]; then
      shift
      _skynet_preview "$*"
    else
      # Try progressive dispatch: "a b c", then "a b", then "a"
      # This allows partial matches to show subcommand help
      if dispatch "$@" 2>/dev/null; then
        exit 0
      fi

      # Check if it's a partial match (category)
      local prefix="$*"
      local matches=()
      ${lib.concatMapStringsSep "\n      " (s: ''
        if [[ "${cmdStr s}" == "$prefix "* || "${cmdStr s}" == "$prefix" ]]; then
          matches+=("${cmdStr s}\t${s.description}")
        fi'') scripts}

      if [[ ''${#matches[@]} -gt 0 ]]; then
        echo "skynet $prefix — available subcommands:"
        echo ""
        for m in "''${matches[@]}"; do
          printf "  %s\n" "$m"
        done
      else
        echo "skynet: unknown command '$*'" >&2
        echo "Run 'skynet --help' for available commands." >&2
        exit 1
      fi
    fi
  '';
in
{
  config = lib.mkIf hasScripts {
    # Symlink the scripts directory to ~/.skynet/scripts
    home.file.".skynet/scripts".source = scriptsDir;

    # Add the skynet CLI to PATH
    home.packages = [ skynetBin ];
  };
}
