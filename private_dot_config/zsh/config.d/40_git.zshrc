# Aliases and utilities for dealing with git

local HERE=$BASH_SOURCE[0]

alias gp="git push --follow-tags"

alias gprune="git fetch -p && git branch -vv | awk '/: gone]/{print \$1}' | xargs -I {} git branch -d \"{}\""
alias gprune!="git fetch -p && git branch -vv | awk '/: gone]/{print \$1}' | xargs -I {} git branch -D \"{}\""

alias glr="git pull --rebase"

gbll () {
  (
    local repo_root=$(git rev-parse --show-toplevel)
    cd "$repo_root" || exit

    local file=$(fzf-file-preview)
    local preview_orientation=$(if_is_landscape "right" "up")

    cat "$file" | awk '{printf("%5d %s\n", NR, $0)}' | \
    fzf --ansi --layout reverse \
        --preview-window "$preview_orientation" \
        --preview "echo {} | awk '{print \$1}' | xargs -I _ sh -c \"git log --color -L_,'+1:${file}'\""
  )
}
alias gsearch="git log --source --all -S"

gff() {
  local git_root=$(git rev-parse --show-toplevel)
  directory=${1:-$git_root}

  local file=$(cd "$directory" && fzf-file-preview)
  local relative_path=$(realpath --relative-to="$(pwd)" "$git_root/$file")

  local string=$(echo $file | fzf --layout=reverse \
      --preview="git log -p --color -S{q} -- $relative_path | delta" \
      --preview-window "up:99%:wrap" \
      --prompt="Enter Search String: " \
      --phony \
      --print-query | head -1)

  echo "Searching for '$string' in '$relative_path'"
  
  local commit=$(git log --color --oneline -S"$string" -- "$relative_path" | fzf \
      --ansi --layout=reverse \
      --preview="git show {1}:'$file' | bat --color always --file-name '$file'" \
      --preview-window "up:80%:wrap" \
      --prompt="Select commit: " | awk '{print $1}')


  git show "$commit:$relative_path" | cat --file-name="$file"
  echo ""
  echo "────────────────────────────────────────────────────────────"
  echo ""
  git show "$commit" --stat
}

rglr () {
  for dir in */; do
    (cd "$dir" && git rev-parse --is-inside-work-tree > /dev/null 2>&1 && (gwip || true) && gfa && glr && (gunwip || true))
  done
}
alias gapf!="gaa && gcan! && (gpf || (glr && gp))"
alias fgapf!="(npm run -s format || exit 0) && gapf!"
alias p="fgapf!"


_GIT_GET_FILENAME_AT_COMMIT() {
  local commit_hash=$1
  local current_filename=$2

  # Use git log to trace the history of the file, including renames
  local old_filename=$(git log --follow --name-status --pretty=format:%H "$current_filename" | \
  awk -v commit="$commit_hash" '
    BEGIN { oldname=current }
    /^[0-9a-f]{40}$/ { lastcommit=$0 }
    /^[AMR]\t/ && lastcommit {
      if (lastcommit == commit) {
        if ($1 == "R") {
          print $3
        } else {
          print $2
        }
        exit
      }
      if ($1 == "R") {
        oldname=$3
      } else {
        oldname=$2
      }
      lastcommit=""
    }  ')

  # Check if old_filename is empty, and if so, fall back to current_filename
  if [ -z "$old_filename" ]; then
    old_filename=$current_filename
  fi

  # Output the file name
  echo "$old_filename"
}


_FZF_GH_PREVIEW_DIFF() {
  local commit=$1
  local file=$2
  local current_file=$(_GIT_GET_FILENAME_AT_COMMIT "$commit" "$file")
  echo $current_file
  git --no-pager diff "$commit^!" -- "$current_file" | diff-so-fancy | sed -E 's/(─{10})/──────/' | GREP_COLORS="mt=30;1;48;5;201" grep --color=always --line-buffered -E "$3|$"
}

_FZF_GH_PREVIEW_NODIFF() {
  local commit=$1
  local file=$2
  local current_file=$(_GIT_GET_FILENAME_AT_COMMIT "$commit" "$file")
  echo $current_file
  git show "$commit:$current_file" | bat --color always --file-name="$current_file" -p -P | GREP_COLORS="mt=30;1;48;5;201" grep --color=always --line-buffered -E "$3|$"
}

gh () {
  (
    local repo_root=$(git rev-parse --show-toplevel)
    cd "$repo_root" || exit
    local file=$(fzf-file-preview)

    local DIFF_PREVIEW_COMMAND='source ~/.config/zsh/config.d/40_git.zshrc && _FZF_GH_PREVIEW_DIFF {1} '$file' {q}'
    local NODIFF_PREVIEW_COMMAND='source ~/.config/zsh/config.d/40_git.zshrc && _FZF_GH_PREVIEW_NODIFF {1} '$file' {q}'

    git log --follow --diff-filter=AMR --color --pretty=format:"%C(yellow)%h %Creset%s%Cblue [%cn]" -- "$file" | fzf \
        --ansi --layout=reverse \
        --preview="bash -c \"$NODIFF_PREVIEW_COMMAND\"" \
        --bind "ctrl-g:change-preview(bash -c \"$DIFF_PREVIEW_COMMAND\")" \
        --bind "ctrl-f:change-preview(bash -c \"$NODIFF_PREVIEW_COMMAND\")" \
        --header "ctrl-f: show file, ctrl-g: show diff" \
        --preview-window "up:80%:wrap" \
        --phony \
        --prompt="Search: "
  )
}

alias gconflict="git diff --name-only --diff-filter=U"

# this function is a bit buggy when checking out local branches
git_checkout_branch() {
  local branch
  local local_branches
  local remote_branches

  local_branches=$(git branch --format="%(refname:short)")
  remote_branches=$(git branch -r | sed 's:remotes/::' | sed 's/^ *//;s/ *$//' | grep -v '\->')

  # Pick any branch
  branch_list=$(echo "$local_branches"; echo "$remote_branches" | grep -v -F "$local_branches" | sort -u)
  if [ -n "$1" ]; then
    branch=$(echo "$branch_list" | fzf --height 8 --layout=reverse --query="$1" --select-1 --exit-0)
  else
    branch=$(echo "$branch_list" | fzf --height 8 --layout=reverse)
  fi

  if [ -n "$branch" ]; then
    local local_branch=$(echo "$branch" | sed 's:.*/::')

    # Check if choice is a local branch
    if echo "$local_branches" | grep -qw "$local_branch"; then
      # Checkout the local branch
      git checkout "$local_branch"
    else
      # Checkout the remote branch (create a local branch first)
      git checkout -b "$local_branch" "$branch"
      git pull --ff-only
    fi
  else
    echo "No branch selected."
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

alias b="gcob"

:
