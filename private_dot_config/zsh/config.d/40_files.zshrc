# Commands for navigating the file system and finding files

alias squash="git rebase -i HEAD~5"

_L_COMMAND="eza -l --icons=always --color-scale=size --git-ignore -I '.git' --group-directories-first -a --git -o --no-user --color=always"
_CAT_COMMAND="bat -P -p --color always --theme 'Visual Studio Dark+'"
_T_COMMAND="tree -L 2 -a -I '.git' --gitignore --dirsfirst"

alias l="$_L_COMMAND"
alias t="$_T_COMMAND"

alias cat="$_CAT_COMMAND"
hexcat () {
  echo $1 \
    | xargs -I{} dd if={} bs=1 count=2048 2>/dev/null \
    | xxd --color=never \
    | awk 'match($0, /^([^:]+:)([[:space:]]+)([0-9A-Fa-f ]+)([[:space:]]+)(.*)/,a){printf "\033[90m%s\033[0m%s\033[97m%s\033[0m%s\033[33m%s\033[0m\n", a[1], a[2], a[3], a[4], a[5]}' \
    | git column --mode="column,dense" --padding=3
}

file-summary () {
  if file --mime $1 | grep -q binary;
    then hexcat $1;
    else cat $1 | head -n 1000;
  fi
}

dir-summary () {
  l $1 | git column --mode="column,dense" --padding=3
}

tree-summary () {
  t $1 | git column --mode="column,dense" --padding=3
}

export FZF_DEFAULT_COMMAND='rg --files --hidden --glob "!**/.git/**"'
FZF_FILE_PREVIEW_COMMAND='source ~/.config/zsh/config.d/40_files.zshrc; file-summary {}'
FZF_FOLDER_PREVIEW_COMMAND='source ~/.config/zsh/config.d/40_files.zshrc; dirname {} | dir-summary'

alias fzf-preview='fzf --layout reverse \
  --preview-window up \
  --preview-window=wrap \
  --bind "ctrl-f:change-preview:'"$FZF_FILE_PREVIEW_COMMAND"'" \
  --bind "ctrl-d:change-preview:'"$FZF_FOLDER_PREVIEW_COMMAND"'" \
  --header "ctrl-f: file preview, ctrl-d: folder preview" \
  --header-first'

alias fzf-file-preview='fzf-preview --preview "'"$FZF_FILE_PREVIEW_COMMAND"'"'
alias fzf-folder-preview='fzf-preview --preview "'"$FZF_FOLDER_PREVIEW_COMMAND"'"'


alias cdf='cd ~ && cd "$(fzf-file-preview | xargs -d "\n" dirname)"'
alias cdo='fzf-file-preview | xargs micro'

function frg {
  result=$(rg --ignore-case --color=always --line-number --no-heading "$@" |
    fzf --ansi \
        --color 'hl:-1:underline,hl+:-1:underline:reverse' \
        --delimiter ':' \
        --preview "$_CAT_COMMAND {1} --highlight-line {2}" \
        --preview-window 'up,60%,border-bottom,+{2}+3/3,~3')
  file=${result%%:*}
  linenumber=$(echo "${result}" | cut -d: -f2)
  if [[ -n "$file" ]]; then
          $EDITOR +"${linenumber}" "$file"
  fi
}

cd_fzf() {
  # Get all directories in the current folder
  local dirs=$(find . -maxdepth 1 -type d -printf "%f\n")

  # Use fzf to pick the closest match to $1
  local selected=$(echo "$dirs" | fzf --query="$1" --select-1 --exit-0)

  # If a directory was selected, cd into it
  if [[ -n "$selected" ]]; then
    cd "$selected" || return
  else
    echo "No matching directory found."
  fi
}

alias c='cd_fzf'


:
