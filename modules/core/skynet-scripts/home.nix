{
  config,
  lib,
  pkgs,
  ...
}:

let
  scripts = config.skynet.cli.scripts;
  hasTs = builtins.any (s: lib.hasSuffix ".ts" (toString s.script)) scripts;

  # Theme colors from Stylix
  s = config.lib.stylix.colors.withHashtag;
  accent = config.skynet.module.desktop.stylix.accent;

  # Common fzf theme args shared across all skynet fzf UIs
  fzfThemeArgs = lib.concatStringsSep " " [
    "--style full"
    "--border --padding 1,2"
    "--input-label ' Search '"
    "--preview-window=right:50%:wrap"
    "--color 'border:${accent},label:${accent}'"
    "--color 'preview-border:${s.base05},preview-label:${s.base06}'"
    "--color 'list-border:${s.base05},list-label:${s.base05}'"
    "--color 'input-border:${accent},input-label:${accent}'"
    "--color 'header-border:${s.base05},header-label:${s.base06}'"
    "--bind 'result:transform-list-label:if [[ -z \$FZF_QUERY ]]; then echo \" \$FZF_MATCH_COUNT items \"; else echo \" \$FZF_MATCH_COUNT matches for [\$FZF_QUERY] \"; fi'"
    "--bind 'focus:transform-preview-label:[[ -n {1} ]] && printf \" %s \" {1}'"
  ];

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
      "${cmd}"|"${cmd} "*)
        shift ${toString nArgs}
        ${
          if isTs then
            ''exec "$SCRIPTS_DIR/node_modules/.bin/tsx" "$SCRIPTS_DIR/${relPath}" "$@"''
          else
            ''exec "$SCRIPTS_DIR/${relPath}" "$@"''
        }
        ;;'';

  # Generate fzf entries: "command\ttitle"
  mkFzfEntry = s: "${cmdStr s}\t${s.title}";

  # --- Zsh completions ---
  # Group scripts by their first command word
  firstWords = lib.unique (map (s: builtins.head s.command) scripts);

  # Scripts that are a single word (leaf commands at top level)
  topLeafs = builtins.filter (s: builtins.length s.command == 1) scripts;

  # For a given first word, get all scripts that start with it and have more words
  subCommandsFor =
    word: builtins.filter (s: builtins.length s.command > 1 && builtins.head s.command == word) scripts;

  # First words that have subcommands
  categories = builtins.filter (w: (subCommandsFor w) != [ ]) firstWords;

  # Generate the _skynet completion function
  skynetCompletion = pkgs.writeText "_skynet" ''
    #compdef skynet

    _skynet() {
      local curcontext="$curcontext" state line

      _arguments -C \
        '1:command:->cmd' \
        '2:subcommand:->sub' \
        && return

      case "$state" in
        cmd)
          local -a top_commands
          top_commands=(
    ${lib.concatMapStringsSep "\n" (
      w:
      let
        subs = subCommandsFor w;
        leaf = builtins.filter (s: builtins.head s.command == w && builtins.length s.command == 1) scripts;
        desc =
          if leaf != [ ] then
            (builtins.head leaf).title
          else if subs != [ ] then
            "${w} commands"
          else
            w;
      in
      "    '${w}:${lib.escape [ "'" ":" ] desc}'"
    ) firstWords}
          )
          _describe 'skynet command' top_commands
          ;;
        sub)
          case "$line[1]" in
    ${lib.concatMapStringsSep "\n" (
      w:
      let
        subs = subCommandsFor w;
        subEntries = lib.concatMapStringsSep "\n" (
          s:
          let
            sub = lib.concatStringsSep " " (builtins.tail s.command);
          in
          "            '${sub}:${lib.escape [ "'" ":" ] s.title}'"
        ) subs;
      in
      ''
            ${w})
                  local -a ${w}_commands
                  ${w}_commands=(
        ${subEntries}
                  )
                  _describe '${w} subcommand' ${w}_commands
                  ;;''
    ) categories}
            *)
              ;;
          esac
          ;;
      esac
    }

    _skynet "$@"
  '';

  # The main skynet CLI script
  skynetBin = pkgs.writeShellScriptBin "skynet" ''
    set -euo pipefail

    SCRIPTS_DIR="$HOME/.skynet/scripts"

    # --- Colorize toilet output with accent ---
    _skynet_colorize() {
      local hex="${accent}"
      hex="''${hex#\#}"
      local r=$((16#''${hex:0:2}))
      local g=$((16#''${hex:2:2}))
      local b=$((16#''${hex:4:2}))
      ${pkgs.gnused}/bin/sed "s/\x1b\[0m/\x1b[0m/g; s/^/\x1b[38;2;''${r};''${g};''${b}m/; s/$/\x1b[0m/"
    }

    # --- Render preview for a command ---
    _skynet_preview() {
      local cmd="$1"
      # Render ASCII art, one word per line
      if [[ "$cmd" == "skynet" ]]; then
        for word in skynet system config; do
          ${pkgs.toilet}/bin/toilet -f future "$word" | _skynet_colorize
        done
      else
        for word in skynet $cmd; do
          ${pkgs.toilet}/bin/toilet -f future "$word" | _skynet_colorize
        done
      fi

      echo ""

      # Show usage text
      case "$cmd" in
        ${lib.concatMapStringsSep "\n        " (s: ''"${cmdStr s}") echo "${s.usage}" ;;'') scripts}
        "skynet") echo "Welcome to skynet." ;;
        *) echo "No usage info available" ;;
      esac
    }

    # --- All registered commands ---
    _SKYNET_CMDS=(
      ${lib.concatMapStringsSep "\n      " (s: ''"${cmdStr s}"'') scripts}
    )

    # --- Resolve prefix-abbreviated args to full command words ---
    # e.g. "f e" -> "fingerprint enroll"
    _skynet_resolve() {
      local -a resolved=()
      local -a candidates=("''${_SKYNET_CMDS[@]}")
      local pos=0

      for arg in "$@"; do
        local -a word_matches=()
        local -a next_candidates=()

        for cmd in "''${candidates[@]}"; do
          read -ra words <<< "$cmd"
          if [[ $pos -lt ''${#words[@]} && "''${words[$pos]}" == "''${arg}"* ]]; then
            next_candidates+=("$cmd")
            local w="''${words[$pos]}"
            local dup=0
            for m in "''${word_matches[@]+"''${word_matches[@]}"}"; do
              [[ "$m" == "$w" ]] && dup=1 && break
            done
            [[ $dup -eq 0 ]] && word_matches+=("$w")
          fi
        done

        if [[ ''${#word_matches[@]} -eq 1 ]]; then
          resolved+=("''${word_matches[0]}")
          candidates=("''${next_candidates[@]}")
          ((pos++))
        else
          # No unique prefix match — pass arg through verbatim
          resolved+=("$arg")
        fi
      done

      echo "''${resolved[*]}"
    }

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
        s: ''echo "  ${lib.fixedWidthString 30 " " (cmdStr s)}${s.title}"''
      ) scripts}
    }

    # --- Interactive fzf picker ---
    interactive() {
      local entries
      entries=$(printf '%b\n' \
        "skynet\tSkynet System Config" \
        ${lib.concatMapStringsSep " \\\n        " (s: ''"${cmdStr s}\t${s.title}"'') scripts}
      )

      local selected
      selected=$(echo "$entries" | ${pkgs.fzf}/bin/fzf \
        ${fzfThemeArgs} \
        --border-label ' SKYNET TUI ' \
        --header-label ' SKYNET ' \
        --header 'Select a script to run' \
        --delimiter=$'\t' \
        --with-nth=2 \
        --preview='skynet _preview {1}' \
        --bind 'focus:+transform-header:{2}' \
      ) || exit 0

      local cmd
      cmd=$(echo "$selected" | cut -f1)
      if [[ "$cmd" == "skynet" ]]; then
        exec skynet
      fi
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
      # Resolve prefix-abbreviated args (e.g. "f e" -> "fingerprint enroll")
      resolved=$(_skynet_resolve "$@")

      # shellcheck disable=SC2086
      if dispatch $resolved; then
        exit 0
      fi

      # Check if it's a partial match (category)
      prefix="$resolved"
      matches=()
      ${lib.concatMapStringsSep "\n      " (s: ''
        if [[ "${cmdStr s}" == "$prefix "* || "${cmdStr s}" == "$prefix" ]]; then
          matches+=("${cmdStr s}\t${s.title}")
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
  config = {
    # Expose the fzf theme args for other modules to use
    skynet.cli.fzfThemeArgs = fzfThemeArgs;

    # Built-in skynet scripts
    skynet.cli.scripts = [
      {
        command = [ "update" ];
        title = "Update flake inputs";
        script = pkgs.writeShellScript "update.sh" ''
          set -euo pipefail
          ${pkgs.toilet}/bin/toilet -f future "update" | cat
          echo ""
          echo "Updating flake inputs..."
          nix flake update ~/repos/personal/dotfiles
        '';
        usage = "Runs nix flake update to fetch the latest versions of all flake inputs.";
      }
    ];

    # Symlink the scripts directory to ~/.skynet/scripts
    home.file.".skynet/scripts".source = scriptsDir;

    # Zsh completions — fpath must be added before compinit (order 570)
    home.file.".skynet/completions/_skynet".source = skynetCompletion;
    programs.zsh.initContent = lib.mkOrder 550 ''
      fpath=(~/.skynet/completions $fpath)
    '';

    # Add the skynet CLI to PATH
    home.packages = [ skynetBin ];
  };
}
