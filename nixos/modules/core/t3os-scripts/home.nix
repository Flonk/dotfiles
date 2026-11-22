{
  config,
  lib,
  pkgs,
  ...
}:

let
  scripts = config.t3os.cli.scripts;

  s = config.lib.stylix.colors.withHashtag;
  accent = config.t3os.module.desktop.stylix.accent;

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

  scriptsDir = pkgs.runCommand "t3os-scripts" { } ''
    mkdir -p $out

    ${lib.concatMapStringsSep "\n" (
      s:
      let
        dir = lib.concatStringsSep "/" (lib.init s.command);
        filename = lib.last s.command + ".sh";
      in
      ''
        mkdir -p $out/${dir}
        cp ${s.script} $out/${dir}/${filename}
        chmod +x $out/${dir}/${filename}
      ''
    ) scripts}
  '';

  cmdStr = s: lib.concatStringsSep " " s.command;

  scriptRelPath =
    s:
    let
      dir = lib.concatStringsSep "/" (lib.init s.command);
      filename = lib.last s.command + ".sh";
    in
    "${dir}/${filename}";

  mkDispatchCase =
    s:
    let
      cmd = cmdStr s;
      nArgs = builtins.length s.command;
      relPath = scriptRelPath s;
    in
    ''
      "${cmd}"|"${cmd} "*)
        shift ${toString nArgs}
        exec "$SCRIPTS_DIR/${relPath}" "$@"
        ;;'';

  dispatchScripts = lib.sort (a: b: builtins.length a.command > builtins.length b.command) scripts;

  firstWords = lib.unique (map (s: builtins.head s.command) scripts);

  subCommandsFor =
    word: builtins.filter (s: builtins.length s.command > 1 && builtins.head s.command == word) scripts;

  categories = builtins.filter (w: (subCommandsFor w) != [ ]) firstWords;

  t3osCompletion = pkgs.writeText "_t3os" ''
    #compdef t3os

    _t3os() {
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
          _describe 't3os command' top_commands
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

    _t3os "$@"
  '';

  t3osBin = pkgs.writeShellScriptBin "t3os" ''
    set -euo pipefail

    SCRIPTS_DIR="$HOME/.t3os/scripts"

    _t3os_colorize() {
      local hex="${accent}"
      hex="''${hex#\#}"
      local r=$((16#''${hex:0:2}))
      local g=$((16#''${hex:2:2}))
      local b=$((16#''${hex:4:2}))
      ${pkgs.gnused}/bin/sed "s/\x1b\[0m/\x1b[0m/g; s/^/\x1b[38;2;''${r};''${g};''${b}m/; s/$/\x1b[0m/"
    }

    _t3os_preview() {
      local cmd="$1"
      if [[ "$cmd" == "t3os" ]]; then
        for word in t3os system config; do
          ${pkgs.toilet}/bin/toilet -f future "$word" | _t3os_colorize
        done
      else
        for word in t3os $cmd; do
          ${pkgs.toilet}/bin/toilet -f future "$word" | _t3os_colorize
        done
      fi

      echo ""

      case "$cmd" in
        ${lib.concatMapStringsSep "\n        " (s: ''"${cmdStr s}") echo "${s.usage}" ;;'') scripts}
        "t3os") echo "Welcome to t3os." ;;
        *) echo "No usage info available" ;;
      esac
    }

    _T3OS_CMDS=(
      ${lib.concatMapStringsSep "\n      " (s: ''"${cmdStr s}"'') scripts}
    )

    _t3os_resolve() {
      local -a resolved=()
      local -a candidates=("''${_T3OS_CMDS[@]}")
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
          pos=$((pos + 1))
        else
          resolved+=("$arg")
        fi
      done

      _RESOLVED=("''${resolved[@]}")
    }

    dispatch() {
      local args=""
      for arg in "$@"; do
        args="''${args:+$args }$arg"
      done

      case "$args" in
        ${lib.concatMapStringsSep "\n        " mkDispatchCase dispatchScripts}
        *)
          return 1
          ;;
      esac
    }

    show_help() {
      echo "t3os - module script runner"
      echo ""
      echo "Usage: t3os <command> [args...]"
      echo "       t3os              Interactive script picker (fzf)"
      echo "       t3os --help       Show this help"
      echo ""
      echo "Available commands:"
      ${lib.concatMapStringsSep "\n      " (
        s: ''echo "  ${lib.fixedWidthString 30 " " (cmdStr s)}${s.title}"''
      ) scripts}
    }

    interactive() {
      local entries
      entries=$(printf '%b\n' \
        "t3os\tT3 OS System Config" \
        ${lib.concatMapStringsSep " \\\n        " (s: ''"${cmdStr s}\t${s.title}"'') scripts}
      )

      local selected
      selected=$(echo "$entries" | ${pkgs.fzf}/bin/fzf \
        ${fzfThemeArgs} \
        --border-label ' T3 OS TUI ' \
        --header-label ' T3 OS ' \
        --header 'Select a script to run' \
        --delimiter=$'\t' \
        --with-nth=2 \
        --preview='t3os _preview {1}' \
        --bind 'focus:+transform-header:{2}' \
      ) || exit 0

      local cmd
      cmd=$(echo "$selected" | cut -f1)
      if [[ "$cmd" == "t3os" ]]; then
        exec t3os
      fi
      dispatch $cmd
    }

    if [[ $# -eq 0 ]]; then
      interactive
    elif [[ "$1" == "--help" || "$1" == "-h" ]]; then
      show_help
    elif [[ "$1" == "_preview" ]]; then
      shift
      _t3os_preview "$*"
    else
      _t3os_resolve "$@"

      if dispatch "''${_RESOLVED[@]}"; then
        exit 0
      fi

      prefix="''${_RESOLVED[*]}"
      matches=()
      ${lib.concatMapStringsSep "\n      " (s: ''
        if [[ "${cmdStr s}" == "$prefix "* || "${cmdStr s}" == "$prefix" ]]; then
          matches+=("${cmdStr s}\t${s.title}")
        fi'') scripts}

      if [[ ''${#matches[@]} -gt 0 ]]; then
        echo "t3os $prefix — available subcommands:"
        echo ""
        for m in "''${matches[@]}"; do
          printf "  %s\n" "$m"
        done
      else
        echo "t3os: unknown command '$*'" >&2
        echo "Run 't3os --help' for available commands." >&2
        exit 1
      fi
    fi
  '';
in
{
  config = {
    t3os.cli.fzfThemeArgs = fzfThemeArgs;

    t3os.cli.scripts = [
      {
        command = [ "upgrade" ];
        title = "Upgrade flake inputs and pinned packages";
        script = pkgs.writeShellScript "upgrade.sh" ''
          set -euo pipefail
          ${pkgs.toilet}/bin/toilet -f future "upgrade" | cat
          echo ""
          echo "Updating flake inputs..."
          nix flake update --flake ~/repos/personal/dotfiles/nixos
          export T3OS_REPO=~/repos/personal/dotfiles
          failed=()
          ${lib.concatMapStringsSep "\n" (u: ''
            echo ""
            echo "Running updater: ${u.name}"
            ${u.script} || failed+=(${lib.escapeShellArg u.name})
          '') config.t3os.cli.updaters}
          if ((''${#failed[@]})); then
            echo ""
            echo "Failed updaters: ''${failed[*]}" >&2
            exit 1
          fi
        '';
        usage = "Runs nix flake update, then every updater registered via t3os.cli.updaters.";
      }
      {
        command = [ "rebuild" ];
        title = "Rebuild home-manager and NixOS config";
        script = pkgs.writeShellScript "rebuild.sh" ''
          set -euo pipefail
          emit() { command -v t3cron >/dev/null 2>&1 && t3cron emit "$@" --source t3os >/dev/null 2>&1 || true; }
          start=$(date +%s)
          stage=home-manager
          emit rebuild/started info "t3os rebuild started" --data "{\"detail\":\"${config.t3os.whoami.installation}\"}"
          trap 'emit rebuild/failed error "t3os rebuild failed in $stage after $(( $(date +%s) - start ))s" --attention' ERR
          echo "Rebuilding home-manager configuration..."
          home-manager switch --flake ~/repos/personal/dotfiles/nixos#${config.t3os.whoami.installation}
          echo ""
          echo "Rebuilding NixOS system configuration..."
          stage=nixos
          sudo /run/current-system/sw/bin/nixos-rebuild switch --no-reexec --flake $HOME/repos/personal/dotfiles/nixos
          gen=$(readlink /nix/var/nix/profiles/system | tr -dc '0-9' || true)
          emit rebuild/done info "t3os rebuild finished in $(( $(date +%s) - start ))s" --data "{\"detail\":\"system generation $gen\"}"
        '';
        usage = "Runs home-manager switch for ${config.t3os.whoami.installation}, then nixos-rebuild switch for ${config.t3os.whoami.host}.";
      }
      {
        command = [ "keys" ];
        title = "Show SSH public keys";
        script = pkgs.writeShellScript "keys.sh" ''
          set -euo pipefail
          BLUE=$'\033[34m'
          RESET=$'\033[0m'
          show_key() {
            local file="$1"
            [ -f "$file" ] || return 0
            local key
            key="$(cat "$file")"
            echo "$key"
            local size=6
            [[ ''${#key} -gt 200 ]] && size=3
            echo "$key" | ${pkgs.qrencode}/bin/qrencode -t PNG --foreground=FFFFFF --background=00000000 -l L -m 2 -s "$size" -o - | ${pkgs.chafa}/bin/chafa
            echo ""
          }
          echo "''${BLUE}## Host Keys''${RESET}"
          show_key /etc/ssh/ssh_host_ed25519_key.pub
          if [[ "''${1:-}" == "--all" ]]; then
            show_key /etc/ssh/ssh_host_rsa_key.pub
          fi
          echo "''${BLUE}## User Keys''${RESET}"
          show_key ~/.ssh/id_ed25519.pub
          if [[ "''${1:-}" == "--all" ]]; then
            show_key ~/.ssh/id_rsa.pub
          fi
        '';
        usage = "Shows public SSH keys (ed25519 by default, --all includes RSA).";
      }
    ];

    home.file.".t3os/scripts".source = scriptsDir;

    home.file.".t3os/completions/_t3os".source = t3osCompletion;
    programs.zsh.initContent = lib.mkOrder 550 ''
      fpath=(~/.t3os/completions $fpath)
    '';

    home.packages = [ t3osBin ];
  };
}
