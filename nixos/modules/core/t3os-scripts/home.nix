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

  childrenOf =
    p:
    let
      n = if p == "" then 0 else builtins.length (lib.splitString " " p);
    in
    lib.unique (
      lib.concatMap (
        e:
        if builtins.length e.command > n && lib.concatStringsSep " " (lib.take n e.command) == p then
          [ (builtins.elemAt e.command n) ]
        else
          [ ]
      ) scripts
    );

  describe =
    path:
    let
      hit = builtins.filter (e: cmdStr e == path) scripts;
    in
    if hit != [ ] then (builtins.head hit).title else "${path} commands";

  zshItem =
    word: desc:
    "'${lib.replaceStrings [ "'" ":" ] [ "'\\''" "\\:" ] word}:${lib.replaceStrings [ "'" ":" ] [ "'\\''" "\\:" ] desc}'";

  t3osCompletion = pkgs.writeText "_t3os" ''
    #compdef t3os

    _t3os() {
      local prefix="''${(j: :)words[2,CURRENT-1]}"
      local -a items
      case "$prefix" in
    ${lib.concatMapStringsSep "\n" (
      p:
      let
        kids = childrenOf p;
      in
      lib.optionalString (kids != [ ]) ''
        ${lib.escapeShellArg p})
          items=(
            ${lib.concatMapStringsSep "\n        " (
              k: zshItem k (describe (lib.concatStringsSep " " (lib.filter (x: x != "") [ p k ])))
            ) kids}
          )
          ;;''
    ) ([ "" ] ++ prefixes)}
        *)
          return 1
          ;;
      esac
      _describe 't3os command' items
    }

    _t3os "$@"
  '';

  t3osTui = pkgs.buildGoModule {
    pname = "t3os-tui";
    version = "0.1.0";
    src = ./tui;
    vendorHash = "sha256-V0HT1olsh/6L60VNGqYXLR39Hky+HeON+fDQP9YPi/g=";
  };

  prefixes = lib.unique (
    lib.concatMap (
      e: map (n: lib.concatStringsSep " " (lib.take n e.command)) (lib.range 1 (builtins.length e.command))
    ) scripts
  );

  manifestBase = pkgs.writeText "t3os-manifest-base.json" (
    builtins.toJSON {
      installation = config.t3os.whoami.installation;
      theme =
        (lib.genAttrs (map (i: "base0${i}") (lib.stringToCharacters "0123456789ABCDEF")) (b: s.${b}))
        // {
          inherit accent;
        };
      entries = map (e: { inherit (e) command title usage pinned preview; }) scripts;
    }
  );

  manifest =
    pkgs.runCommand "t3os-manifest.json"
      {
        nativeBuildInputs = [
          pkgs.toilet
          pkgs.jq
        ];
      }
      ''
        echo '{}' > banners.json
        ${lib.concatMapStringsSep "\n" (p: ''
          art=$(toilet -f future -- ${lib.escapeShellArg p})
          jq --arg k ${lib.escapeShellArg p} --arg v "$art" '. + {($k): $v}' banners.json > b.tmp
          mv b.tmp banners.json
        '') ([ "t3os" ] ++ prefixes)}
        jq --slurpfile b banners.json '. + {banners: $b[0]}' ${manifestBase} > $out
      '';

  t3osBin = pkgs.writeShellScriptBin "t3os" ''
    set -euo pipefail

    SCRIPTS_DIR="$HOME/.t3os/scripts"

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
      echo "       t3os              Interactive command browser"
      echo "       t3os --help       Show this help"
      echo ""
      echo "Available commands:"
      ${lib.concatMapStringsSep "\n      " (
        s: ''printf '  %-34s%s\n' ${lib.escapeShellArg (cmdStr s)} ${lib.escapeShellArg s.title}''
      ) scripts}
    }

    interactive() {
      exec ${t3osTui}/bin/t3os-tui ${manifest}
    }

    if [[ $# -eq 0 ]]; then
      interactive
    elif [[ "$1" == "--help" || "$1" == "-h" ]]; then
      show_help
    else
      _t3os_resolve "$@"

      if dispatch "''${_RESOLVED[@]}"; then
        exit 0
      fi

      prefix="''${_RESOLVED[*]}"
      matches=()
      ${lib.concatMapStringsSep "\n      " (s: ''
        if [[ "${cmdStr s}" == "$prefix "* || "${cmdStr s}" == "$prefix" ]]; then
          printf -v line '%-34s%s' ${lib.escapeShellArg (cmdStr s)} ${lib.escapeShellArg s.title}
          matches+=("$line")
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
        command = [ "info" ];
        title = "Welcome to T3 OS";
        pinned = true;
        preview = true;
        script = pkgs.writeShellScript "info.sh" ''
          set -uo pipefail
          flake="$HOME/repos/personal/dotfiles/nixos"
          if [ -t 1 ] || [ -n "''${T3OS_COLOR:-}" ]; then
            hex=${lib.escapeShellArg accent}
            hex=''${hex#\#}
            A=$(printf '\033[38;2;%d;%d;%dm' 0x''${hex:0:2} 0x''${hex:2:2} 0x''${hex:4:2})
            D=$'\033[2m'
            B=$'\033[1m'
            R=$'\033[0m'
          else
            A= D= B= R=
          fi
          row() { printf '%s%-13s%s %s\n' "$D" "$1" "$R" "$2"; }

          printf '%sWelcome to T3 OS.%s\n\n' "$B" "$R"
          row user "$(id -un)"
          row host ${lib.escapeShellArg config.t3os.whoami.host}
          row installation ${lib.escapeShellArg config.t3os.whoami.installation}
          row os "$(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME")"
          row kernel "$(uname -r)"
          s=$(cut -d. -f1 /proc/uptime)
          row uptime "$((s / 86400))d $((s % 86400 / 3600))h $((s % 3600 / 60))m"
          gen=$(readlink /nix/var/nix/profiles/system 2>/dev/null | tr -dc '0-9')
          [ -n "$gen" ] && row generation "$gen, built $(date -d "@$(stat -c %Y /nix/var/nix/profiles/system)" '+%Y-%m-%d %H:%M')"
          echo
          row flake "''${flake/#$HOME/\~}"
          if [ -d "$flake/.git" ] || git -C "$flake" rev-parse >/dev/null 2>&1; then
            row commit "$A$(git -C "$flake" log -1 --format='%h' 2>/dev/null)$R $(git -C "$flake" log -1 --format='%s' 2>/dev/null)"
            row branch "$(git -C "$flake" branch --show-current 2>/dev/null)"
            dirty=$(git -C "$flake" status --porcelain 2>/dev/null | wc -l)
            if [ "$dirty" -gt 0 ]; then row changes "$dirty uncommitted"; else row changes "clean"; fi
          fi
          echo
          row commands "${toString (builtins.length scripts)}"
        '';
        usage = "Shows who and where you are: user, host, installation, OS, kernel, uptime, system generation, and the dotfiles flake with its latest commit.";
      }
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
          emit rebuild/started info "Started a t3os rebuild of ${config.t3os.whoami.installation}." --data "{\"detail\":\"${config.t3os.whoami.installation}\"}"
          trap 'emit rebuild/failed error "t3os rebuild failed in $stage after $(( $(date +%s) - start ))s." --attention' ERR
          echo "Rebuilding home-manager configuration..."
          home-manager switch --flake ~/repos/personal/dotfiles/nixos#${config.t3os.whoami.installation}
          echo ""
          echo "Rebuilding NixOS system configuration..."
          stage=nixos
          sudo /run/current-system/sw/bin/nixos-rebuild switch --no-reexec --flake $HOME/repos/personal/dotfiles/nixos
          gen=$(readlink /nix/var/nix/profiles/system | tr -dc '0-9' || true)
          emit rebuild/done info "t3os rebuild finished in $(( $(date +%s) - start ))s." --data "{\"detail\":\"system generation $gen\"}"
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
