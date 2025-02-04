# Commands for navigating the file system and finding files

alias squash="git rebase -i HEAD~5"

_L_COMMAND="eza -l --icons=always --color-scale=size --git-ignore -I '.git' --group-directories-first -a --git -o --no-user --color=always"
_CAT_COMMAND="bat -P -p --color always --theme 'Visual Studio Dark+'"
_T_COMMAND="tree -L 2 -a -I '.git' --gitignore --dirsfirst"

alias l="$_L_COMMAND"
alias t="$_T_COMMAND"
alias cat="$_CAT_COMMAND"

export FZF_DEFAULT_COMMAND='rg --files --hidden --glob "!**/.git/**"'
FZF_FILE_PREVIEW_COMMAND='if file --mime {} | grep -q binary; then head -c 1MB {}; else '$_CAT_COMMAND' {} | head -n 1000; fi'
FZF_FOLDER_PREVIEW_COMMAND='dirname {} | xargs -I _ tree -C -L 2 --gitignore --dirsfirst _'

_FILE_PREVIEW () {
  file=$1
  if file --mime $1 | grep -q binary; then
    head -c 1MB $1
  else
   bat -P -p --color always --theme 'Visual Studio Dark+' $1 | head -n 1000
  fi
}

_FOLDER_PREVIEW () {
  dirname $1 | xargs -I {_] tree -C -L 2 --gitignore --dirsfirst {_]
}

_BOTH_PREVIEW () {
  file=$1
  term_cols=$(tput cols)
  cols=$((term_cols / 2))
  file_preview_wrapped=$(_FILE_PREVIEW $file | bat -P -p --color always --terminal-width=40)
  folder_preview_wrapped=$(_FOLDER_PREVIEW $file | cut -c 1-40)
  pr -m <(echo $folder_preview_wrapped) <(echo $file_preview_wrapped)
}


alias fzf-preview='fzf --layout reverse \
  --preview-window up \
  --preview-window=wrap \
  --bind "ctrl-f:change-preview:'"$FZF_FILE_PREVIEW_COMMAND"'" \
  --bind "ctrl-d:change-preview:'"$FZF_FOLDER_PREVIEW_COMMAND"'" \
  --header "ctrl-f: file preview, ctrl-d: folder preview" \
  --header-first'

alias fzf-file-preview='fzf-preview --preview "'"$FZF_FILE_PREVIEW_COMMAND"'"'
alias fzf-folder-preview='fzf-preview --preview "'"$FZF_FOLDER_PREVIEW_COMMAND"'"'

both () {
  
}

alias cdf='cd ~ && cd "$(fzf-folder-preview | xargs -d "\n" dirname)"'
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
