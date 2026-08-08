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

gcobr () {
  git fetch --prune >/dev/null 2>&1
  # Strip just the first path segment (the remote name) so multi-segment
  # branch names like feature/foo survive intact.
  local branches
  branches=$(git branch -r | grep -v ' -> ' | awk '{sub(/^[ \t]*[^/]+\//,""); print}' | sort -u)
  local branch
  if [ -n "$1" ]; then
    branch=$(echo "$branches" | fzf --query="$1" --select-1 --exit-0)
  else
    branch=$(echo "$branches" | fzf --height 8 --layout=reverse)
  fi
  [ -n "$branch" ] && git checkout "$branch"
}

figlet-all() {
  local fontdir
  fontdir=$(figlet -I2)
  for font in "$fontdir"/*.flf(N) "$fontdir"/*.tlf(N); do
      font_name=$(basename "$font")
      font_name=${font_name%.*}
      figlet -f "$font_name" "$1"
      echo "$font_name"
      echo
      echo
  done
}

figlet-fzf() {
  local fontdir
  local -a out
  fontdir=$(figlet -I2)
  out=("${(@f)$(
    for f in "$fontdir"/*.flf(N) "$fontdir"/*.tlf(N); do
      print -r -- "${${f:t}:r}"
    done | sort | fzf --disabled --print-query --query="${*:-figlet}" \
      --layout=reverse --preview 'figlet -f {} {q}' --preview-window='up,70%,wrap'
  )}") || return
  (( $#out < 2 )) && return
  figlet -f "$out[2]" "$out[1]"
}

_nix-shell-run() {
  nix-shell -p "$1" --command "$1"
}

qr() {
  nix-shell -p qrencode --run "qrencode -t UTF8i \"${*}\""
}

mount-sd-card() {
  sudo mkdir -p /mnt/sdcard
  sudo mount /dev/mmcblk0p1 /mnt/sdcard
  cd /mnt/sdcard || return 1
}

download-cert-chain() {
  local url="$1"
  if [[ -z "$url" ]]; then
    echo "Usage: download-cert-chain <url>"
    return 1
  fi
  
  openssl s_client -connect "$url:443" -servername "$url" -showcerts </dev/null 2>/dev/null \
    | sed -n '/BEGIN CERTIFICATE/,/END CERTIFICATE/p' > chain.pem
  
  awk 'BEGIN{c=0} /BEGIN CERTIFICATE/{c++} {print > ("chain-" c ".crt")}' chain.pem
  
  for f in chain-*.crt; do
    echo "== $f =="
    openssl x509 -in "$f" -noout -subject -issuer -ext basicConstraints
  done
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

hex() {
  hexdump --color=always \
    -e '"%07.7_ax_L[yellow]   "' \
    -e '16/1 "%02x_L[blue] " "   "' \
    -e '16/1 "%_p_L[brightyellow] " "\n"' \
    "$@" | less -R
}

export GIT_SSL_NO_VERIFY=1

# walk from $1 down at most $2 levels, calling $3 on every repo found; a repo is
# never descended into
_rglr_walk() {
  local dir="$1" depth="$2" action="$3" sub
  if [[ -d "$dir/.git" ]]; then
    "$action" "$dir"
    return
  fi
  (( depth <= 0 )) && return
  for sub in "$dir"/*(N/); do
    _rglr_walk "$sub" $(( depth - 1 )) "$action"
  done
}

_rglr_header() {
  local label="$1" rule="${(l:$(( ${#1} + 2 ))::─:)}"
  printf "\033[1;90m╭%s╮\n│\033[0m \033[1;34m%s\033[0m \033[1;90m│\n╰%s╯\033[0m\n" \
    "$rule" "$label" "$rule"
}

_rglr_pull() {
  local dir="$1"
  _rglr_header "${dir#./}"
  (
    cd "$dir" && git add -A
    git rm $(git ls-files --deleted) 2>/dev/null
    git commit --no-verify --no-gpg-sign --message "--wip-- [skip ci]" &&
    git fetch --all --tags --prune &&
    git pull &&
    git rev-list --max-count=1 --format="%s" HEAD | grep -q -- "--wip--" && git reset HEAD~1
  )
}

_rglr_pull_default_branch() {
  local dir="$1" branch
  (
    cd "$dir" || exit
    if git show-ref --verify --quiet refs/heads/develop; then
      branch=develop
    else
      branch=main
    fi
    _rglr_header "${dir#./} ($branch)"
    git add -A
    git rm $(git ls-files --deleted) 2>/dev/null
    git commit --no-verify --no-gpg-sign --message "--wip-- [skip ci]" &&
    git checkout "$branch" &&
    git fetch --all --tags --prune &&
    git pull
  )
}

# rglr [depth] — for every repo up to $depth levels down: stash WIP, fetch, pull, restore WIP
rglr() {
  _rglr_walk . "${1:-3}" _rglr_pull
}

# rglr! [depth] — same, but checkout develop (or main) before pulling
rglr!() {
  _rglr_walk . "${1:-3}" _rglr_pull_default_branch
}
