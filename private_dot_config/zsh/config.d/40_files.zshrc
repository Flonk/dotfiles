# Commands for navigating the file system and finding files

alias squash="git rebase -i HEAD~5"
alias t="tree -L 2 -a -I '.git' --gitignore --dirsfirst"
alias cat="bat -P -p --color always --theme 'Visual Studio Dark+'"

export FZF_DEFAULT_COMMAND='rg --files'
FZF_FILE_PREVIEW_COMMAND='if file --mime {} | grep -q binary; then head -c 1MB {}; else bat -p --color always {} | head -n 1000; fi'
FZF_FOLDER_PREVIEW_COMMAND='dirname {} | xargs -I _ tree -C -L 2 --gitignore --dirsfirst _'

alias fzf-preview='fzf --layout reverse \
  --preview-window up \
  --preview-window=wrap \
  --bind "ctrl-f:change-preview:'"$FZF_FILE_PREVIEW_COMMAND"'" \
  --bind "ctrl-d:change-preview:'"$FZF_FOLDER_PREVIEW_COMMAND"'" \
  --header "ctrl-f: file preview, ctrl-d: folder preview" \
  --header-first'

alias fzf-file-preview='fzf-preview --preview "'"$FZF_FILE_PREVIEW_COMMAND"'"'
alias fzf-folder-preview='fzf-preview --preview "'"$FZF_FOLDER_PREVIEW_COMMAND"'"'

alias c='cd ~ && cd "$(fzf-folder-preview | xargs -d "\n" dirname)"'
alias o='fzf-file-preview | xargs micro'

function frg {
  result=$(rg --ignore-case --color=always --line-number --no-heading "$@" |
    fzf --ansi \
        --color 'hl:-1:underline,hl+:-1:underline:reverse' \
        --delimiter ':' \
        --preview "bat --color=always {1} --theme='Solarized (light)' --highlight-line {2}" \
        --preview-window 'up,60%,border-bottom,+{2}+3/3,~3')
  file=${result%%:*}
  linenumber=$(echo "${result}" | cut -d: -f2)
  if [[ -n "$file" ]]; then
          $EDITOR +"${linenumber}" "$file"
  fi
}

:
