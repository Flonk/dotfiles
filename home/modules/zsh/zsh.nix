{
  pkgs,
  config,
  lib,
  ...
}:
{

  programs.zsh = {
    enable = true;

    # relative to ~
    dotDir = "${config.home.homeDirectory}/.config/zsh";
    enableCompletion = true;
    history.size = 10000;
    history.share = true;

    plugins = [
      {
        name = "powerlevel10k-config";
        src = ./.;
        file = "p10k.zsh";
      }
      {
        name = "zsh-powerlevel10k";
        src = "${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/";
        file = "powerlevel10k.zsh-theme";
      }
    ];

    initContent =
      let
        init = lib.mkBefore ''
          # Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
          # Initialization code that may require console input (password prompts, [y/n]
          # confirmations, etc.) must go above this block; everything else may go below.
          if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
            source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
          fi

          # autoSuggestions config
          setopt hist_reduce_blanks # remove superfluous blanks from history items
          setopt inc_append_history # save history entries as soon as they are entered

          # auto complete options
          setopt auto_list # automatically list choices on ambiguous completion
          setopt auto_menu # automatically use menu completion
          zstyle ':completion:*' menu select # select completions with arrow keys
          zstyle ':completion:*' group-name "" # group results by category
          zstyle ':completion:::::' completer _expand _complete _ignored _approximate # enable approximate matches for completion

          cd_fzf() {
            # Get all directories in the current folder
            local dirs=$(find . -maxdepth 1 -type d -printf "%f\n")

            # Use fzf to pick the closest match to $1
            local selected=$(echo "$dirs" | fzf --layout reverse --height 8 --query="$1" --select-1 --exit-0)

            # If a directory was selected, cd into it
            if [[ -n "$selected" ]]; then
              cd "$selected" || return
            else
              echo "No matching directory found."
            fi
          }

          npmrun_fzf() {
            (
              set -e

              local root
              root=$(npm prefix 2>/dev/null) || { echo "Not inside an npm project." >&2; exit 1; }
              cd "$root" || exit 1

              # List script names (safe if no scripts)
              local scripts
              scripts=$(jq -r '.scripts | keys[]?' package.json) || { echo "Failed to read package.json" >&2; exit 1; }

              local script
              if [ -n "$1" ]; then
                script=$(printf '%s\n' "$scripts" | fzf --query="$1" --select-1 --exit-0)
              else
                script=$(printf '%s\n' "$scripts" | fzf --height 8 --layout=reverse)
              fi

              if [ -n "$script" ]; then
                echo "+ npm run $script" >&2
                npm run "$script"
              else
                echo "No matching script found."
              fi
            )
          }

          open_fzf () {
            if [ -n "$1" ]; then
              xdg-open "$(find . -maxdepth 1 | fzf --query="$1" --select-1 --exit-0)"
            else
              xdg-open "$(find . -maxdepth 1 | fzf --height 8 --layout=reverse)"
            fi
          }


          gcob () {
            if [ -n "$1" ]; then
              # Use the provided argument as a filter for fzf
              git checkout $(git branch | fzf --query="$1" --select-1 --exit-0)
            else
              # No argument provided, just show the branches for selection
              git checkout $(git branch | fzf --height 8 --layout=reverse)
            fi
          }

          figlet-all() {
            for font in /usr/share/figlet/*.tlf; do
                font_name=$(basename "$font" .tlf)
                figlet -f $font_name "$1"
                echo "$font_name"
                echo
                echo
            done
          }

          _nix-shell-run() {
            nix-shell -p "$1" --command "$1"
          }

          qr() {
            nix-shell -p qrencode --run "qrencode -t UTF8i \"''${*}\""
          }

          mount-sd-card() {
            sudo mkdir -p /mnt/sdcard
            sudo mount /dev/mmcblk0p1 /mnt/sdcard
            cd /mnt/sdcard || return 1
          }

          squash_wip() {
            local WIP_MSG="--wip-- [skip ci]"
            local count=0

            # ensure we're in a git repo
            git rev-parse --git-dir >/dev/null 2>&1 || {
              echo "❌ Not a git repository."
              return 1
            }

            # count consecutive WIP commits from HEAD
            while read -r sha; do
              local subj
              subj="$(git show -s --format=%s "$sha")"
              if [[ "$subj" == "$WIP_MSG" ]]; then
                ((count++))
              else
                break
              fi
            done < <(git rev-list --first-parent HEAD)

            if (( count == 0 )); then
              echo "ℹ️  No WIP commits at HEAD with subject: \"$WIP_MSG\""
              return 0
            fi

            if (( count == 1 )); then
              echo "✏️  Only one WIP commit — opening editor to reword it..."
              git commit --amend
              return 0
            fi

            echo "🔨 Squashing $count WIP commits into one..."
            git reset --soft "HEAD~$count"
            git commit
            echo "✅ Done."
          }

        '';

        end = lib.mkAfter ''
          if [[ -n "$IS_INITIAL_SHELL" ]]; then
            
          else
            fortune | cowsay
          fi
        '';

      in
      lib.mkMerge [
        init
        end
      ];

    oh-my-zsh = {
      enable = true;
      # Standard OMZ plugins pre-installed to $ZSH/plugins/
      # Custom OMZ plugins are added to $ZSH_CUSTOM/plugins/
      # Enabling too many plugins will slowdown shell startup
      plugins = [
        "aliases"
        "git"
        "docker"
        "docker-compose"
        "isodate"
        "kubectl"
        "z"
      ];
      extraConfig = ''
        # Display red dots whilst waiting for completion.
        COMPLETION_WAITING_DOTS="true"
      '';
    };

    sessionVariables = {
      EDITOR = "micro";
    };

    shellAliases = {
      # Overrides those provided by OMZ libs, plugins, and themes.
      # For a full list of active aliases, run `alias`.

      ##### Navigation
      cat = "bat -P -p --color always --theme 'Visual Studio Dark+'";
      t = "tree -L 2 -a -I '.git' --gitignore --dirsfirst";
      l = "eza -l --group --color-scale=size --git-ignore -I '.git' --group-directories-first -a --git -o --color=always";
      c = "cd_fzf";
      o = "open_fzf";

      ##### Nix
      ne = "nix-instantiate --eval";
      nb = "nix-build";
      ns = "nix-shell";
      s = "nix-shell -p";
      run = "_nix-shell-run";
      appimage = "nix run nixpkgs#appimage-run --";
      hash = "nix-prefetch-url --unpack"; # url is ref like https://github.com/normen/whatscli/archive/refs/tags/v1.0.11.tar.gz

      ##### Git
      gprune = "git fetch -p && git branch -vv | awk '/: gone]/{print \$1}' | xargs -I {} git branch -d \"{}\"";
      "gprune!" =
        "git fetch -p && git branch -vv | awk '/: gone]/{print \$1}' | xargs -I {} git branch -D \"{}\"";
      b = "gcob";
      squash = "squash_wip";

      ##### Docker
      dka = "docker ps -q | xargs docker stop | xargs docker rm";
      "dka!" = "docker ps -aq | xargs docker stop | xargs docker rm";
      "dkav!" = "docker volume ls | xargs docker volume rm";
      "dk!" = "dka! && dkav!";

      ##### Assorted
      future = "toilet -f future";
      x = "sudo env \"PATH=$PATH\"";
      n = "npmrun_fzf";

      ##### Musescore -- the nix package does not work
      musescore = "nix run nixpkgs#appimage-run -- ~/Downloads/MuseScore-Studio-4.5.2.251141401-x86_64.AppImage &";
    };
  };
}
/*
  old stuff.. evalulate if still needed

  # ansible
  export ANSIBLE_NOCOWS=1

  # azure
  az-select-subscription() {
    az account list --output table | tail -n +3 | fzf --layout reverse --height 10 --header "Select Azure subscription" | awk '{print $(NF-3)}' | xargs -I {} az account set --subscription {}
  }
*/
