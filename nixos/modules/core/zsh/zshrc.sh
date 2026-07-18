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

lol() {
  local branch ticket me verbose=0

  # bail early if not in repo
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    echo "not a git repository" >&2
    return 1
  }

  usage() {
    cat <<EOF
usage: gitlog [options]

options:
  --ticket <TICKET>   override detected ticket (PROJECTKEY-NUMBER)
  --author <NAME>     override git user.name
  --verbose           show merge commits
  --help              show this help

examples:
  gitlog
  gitlog --verbose
  gitlog --ticket ABC-123
  gitlog --author "Florian Schindler"
EOF
  }

  while [ $# -gt 0 ]; do
    case "$1" in
      --ticket) ticket="$2"; shift 2 ;;
      --author) me="$2"; shift 2 ;;
      --verbose) verbose=1; shift ;;
      --help) usage; return 0 ;;
      *) echo "unknown option: $1"; usage; return 1 ;;
    esac
  done

  branch="$(git symbolic-ref --short HEAD 2>/dev/null)"

  # auto-detect if not overridden
  : "${ticket:=$(echo "$branch" | grep -oE '[A-Z]+-[0-9]+')}"
  : "${me:=$(git config user.name)}"

  git log --date=iso-local --color=always \
    --pretty=format:"%h|%ad|%an|%s" |
  awk -F'|' -v tk="$ticket" -v me="$me" -v verbose="$verbose" '
  function lower(s){ return tolower(s) }
  function trim(s){ sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }

  BEGIN {
    me_l = lower(trim(me))
    n = split(me_l, p, /[[:space:]]+/)
    two = (n==2)
    if (two) {
      fn=p[1]; ln=p[2]
      r1 = fn ".*[[:space:]]*" ln
      r2 = ln ".*[[:space:]]*" fn
    }
  }

  {
    hash=$1
    date_raw=$2
    author_raw=$3
    msg=$4

    # hide merge commits unless verbose
    if (!verbose && msg ~ /^Merge branch/)
      next

    # format date: remove seconds and timezone
    # input: 2024-01-13 14:30:45 +0100
    # output: 2024-01-13 14:30
    sub(/:[0-9][0-9] [+-][0-9]+$/, "", date_raw)
    date = date_raw

    author_fmt = sprintf("%20s", substr(author_raw,1,20))

    # parse ticket number from message
    ticket_str = "    "

    if (match(msg, /[A-Z]+-[0-9]+/)) {
      full_ticket = substr(msg, RSTART, RLENGTH)
      if (match(full_ticket, /[0-9]+$/)) {
        ticket_num = substr(full_ticket, RSTART)
        ticket_str = sprintf("%04d", ticket_num)
      }
    }

    # truncate + pad message
    msg_clean = sprintf("%-60s", substr(msg, 1, 60))

    # border
    border = "\033[1;90m│\033[0m"

    final_msg = "\033[33m" ticket_str "\033[0m " border " " msg_clean

    bold_line = (tk != "" && index(msg, tk))
    pre = bold_line ? "\033[1m" : ""
    post = bold_line ? "\033[0m" : ""

    # chore slightly faint
    msg_color = ""
    if (msg ~ /chore/i)
      msg_color = "\033[37m"

    # detect self
    a_l = lower(trim(author_raw))
    is_me = two ? (a_l ~ r1 || a_l ~ r2) : (a_l == me_l)

    author_out = author_fmt
    if (is_me)
      author_out = "\033[1;31m" author_fmt "\033[0m" (bold_line ? "\033[1m" : "")

    printf "%s\033[33m%s\033[0m%s \033[32m%s\033[0m%s \033[36m%s\033[0m%s %s%s%s\n",
      pre, hash, pre,
      date, pre,
      author_out, pre,
      msg_color, final_msg, "\033[0m",
      post
  }' | less -R
}

# rlol — recursive lol: my commits across every git repo under the cwd (or given dir)
rlol() {
  local root="${1:-.}" me mail

  me="$(git config user.name)"
  mail="$(git config user.email)"
  : "${me:=$(git -C "$root" config user.name 2>/dev/null)}"
  : "${mail:=$(git -C "$root" config user.email 2>/dev/null)}"

  if [ -z "$me" ] && [ -z "$mail" ]; then
    echo "could not determine author (set git user.name / user.email)" >&2
    return 1
  fi

  {
    # find every git repo under root; emit all commits tagged with the repo name,
    # plus author name + email so awk can decide who's "me"
    find "$root" -type d -name .git -prune 2>/dev/null | while read -r gitdir; do
      local repo="${gitdir%/.git}"
      local name="${repo##*/}"
      git -C "$repo" log --no-merges --date=iso-local \
        --pretty=format:"%ad|$name|%h|%an|%ae|%s" 2>/dev/null
      echo
    done
  } | awk -F'|' -v me="$me" -v mail="$mail" '
    function lower(s){ return tolower(s) }
    function trim(s){ sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }

    BEGIN {
      me_l = lower(trim(me))
      mail_l = lower(trim(mail))
      n = split(me_l, p, /[[:space:]]+/)
      two = (n == 2)
      if (two) {
        fn = p[1]; ln = p[2]
        r1 = fn ".*[[:space:]]*" ln
        r2 = ln ".*[[:space:]]*" fn
      }
    }

    {
      if (NF < 6) next
      date_raw=$1; repo=$2; hash=$3; author=$4; email=$5
      # subject may contain "|" — rejoin fields 6..NF
      subj=$6
      for (i=7; i<=NF; i++) subj = subj "|" $i

      # decide if this commit is mine
      a_l = lower(trim(author))
      e_l = lower(trim(email))
      is_me = 0
      if (mail_l != "" && e_l == mail_l) is_me = 1
      else if (me_l != "") {
        if (two) is_me = (a_l ~ r1 || a_l ~ r2)
        else     is_me = (a_l == me_l)
      }
      if (!is_me) next

      # trim seconds + timezone: "2024-01-13 14:30:45 +0100" -> "2024-01-13 14:30"
      sub(/:[0-9][0-9] [+-][0-9]+$/, "", date_raw)

      print date_raw "\t" repo "\t" hash "\t" subj
    }
  ' | sort -r | awk -F'\t' '
    {
      date_raw=$1; repo=$2; hash=$3; subj=$4
      repo_fmt = sprintf("%-20s", substr(repo, 1, 20))
      subj_fmt = sprintf("%-60s", substr(subj, 1, 60))
      border = "\033[1;90m│\033[0m"

      printf "\033[35m%s\033[0m %s \033[33m%s\033[0m %s \033[32m%s\033[0m %s %s\n",
        repo_fmt, border, hash, border, date_raw, border, subj_fmt
    }' | less -R
}

# rglr — for every subfolder: stash WIP, fetch, pull, restore WIP
rglr() {
  local dir
  find . -maxdepth 1 -mindepth 1 -type d | while read -r dir; do
    [[ -d "$dir/.git" ]] || continue
    echo "▶ ${dir#./}"
    (
      cd "$dir" && git add -A
      git rm $(git ls-files --deleted) 2>/dev/null
      git commit --no-verify --no-gpg-sign --message "--wip-- [skip ci]" &&
      git fetch --all --tags --prune &&
      git pull &&
      git rev-list --max-count=1 --format="%s" HEAD | grep -q -- "--wip--" && git reset HEAD~1
    )
  done
}

# rglr! — for every subfolder: stash WIP, checkout develop (or main), fetch, pull
rglr!() {
  local dir branch
  find . -maxdepth 1 -mindepth 1 -type d | while read -r dir; do
    [[ -d "$dir/.git" ]] || continue
    (
      cd "$dir" || exit
      if git show-ref --verify --quiet refs/heads/develop; then
        branch=develop
      else
        branch=main
      fi
      echo "▶ ${dir#./} ($branch)"
      git add -A
      git rm $(git ls-files --deleted) 2>/dev/null
      git commit --no-verify --no-gpg-sign --message "--wip-- [skip ci]" &&
      git checkout "$branch" &&
      git fetch --all --tags --prune &&
      git pull
    )
  done
}
