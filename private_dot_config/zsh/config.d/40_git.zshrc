# Aliases and utilities for dealing with git

alias gp="git push --follow-tags"

alias gprune="git fetch -p && git branch -vv | awk '/: gone]/{print \$1}' | xargs -I {} git branch -d \"{}\""
alias gprune!="git fetch -p && git branch -vv | awk '/: gone]/{print \$1}' | xargs -I {} git branch -D \"{}\""

alias glr="git pull --rebase"
gbll () {
    # check git history of a single line of code
    local file=$(fzf)
  cat "$file" | awk '{printf("%5d %s\n", NR, $0)}' \
    | fzf --layout reverse --preview-window up --preview "echo {} | awk '{print \$1}' | xargs -I _ sh -c \"git log --color -L_,'+1:${file}'\""
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
    (cd "$dir" && git rev-parse --is-inside-work-tree > /dev/null 2>&1 && (gwip || true) && glr && (gunwip || true))
  done
}
alias gapf!="gaa && gcan! && (gpf || (glr && gp))"

gh () {
  local file=$(fzf-file-preview)
  local DIFF_PREVIEW_COMMAND="git diff HEAD {1} -- '$file' | delta --color-only | GREP_COLORS='mt=30;1;48;5;201' grep --color=always --line-buffered -E '{q}|$'"
  local NODIFF_PREVIEW_COMMAND="git show {1}:'$file' | bat --color always --file-name '$file' | GREP_COLORS='mt=30;1;48;5;201' grep --color=always --line-buffered -E '{q}|$'"

  git log --color --pretty=format:"%C(yellow)%h %Creset%s%Cblue [%cn]" | fzf \
      --ansi --layout=reverse \
      --preview="$NODIFF_PREVIEW_COMMAND" \
      --bind "ctrl-d:change-preview:'"$DIFF_PREVIEW_COMMAND"'" \
      --bind "ctrl-f:change-preview:'"$NODIFF_PREVIEW_COMMAND"'" \
      --header "ctrl-f: disable diff, ctrl-d: enable diff" \
      --preview-window "up:80%:wrap" \
      --phony \
      --prompt="Search: "
}

alias gconflict="git diff --name-only --diff-filter=U"
gcob () {
  git checkout $(git branch | fzf --height 8 --layout=reverse)
}

:
