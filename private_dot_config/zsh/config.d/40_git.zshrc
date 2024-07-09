# Aliases and utilities for dealing with git

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
  local directory
  if [[ -n $1 ]]; then
    directory="$1"
  else
    directory=$git_root
  fi

  local file=$(cd "$directory" && fzf-file-preview)
  local relative_path=$(realpath --relative-to="$git_root" "$file")

  local string=$(echo $file | fzf --layout=reverse \
      --preview="git log -p --color -S{q} -- $file | delta" \
      --preview-window "up:99%:wrap" \
      --prompt="Enter Search String: " \
      --print-query)
  
  local commit=$(git log --color --oneline -S"$string" -- "$file" | fzf \
      --ansi --layout=reverse \
      --preview="cd '$directory' && git show {1}:'$relative_path' | bat --color always --file-name '$file'" \
      --preview-window "up:80%:wrap" \
      --prompt="Select commit: " | awk '{print $1}')

  git show "$commit:$relative_path"
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
        --header "ctrl-f: disable diff, ctrl-g: enable diff" \
        --preview-window "up:80%:wrap" \
        --phony \
        --prompt="Search: "
  )
}

alias gconflict="git diff --name-only --diff-filter=U"
git_checkout_branch () {
  if [ -n "$1" ]; then
    git checkout $(git branch | fzf --height 8 --layout=reverse --query="$1" --select-1 --exit-0)
  else
    git checkout $(git branch | fzf --height 8 --layout=reverse)
  fi
}
alias b="git_checkout_branch"

:
