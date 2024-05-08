# Global variables

if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='nano'
 else
  export EDITOR='nvim'
fi

alias e="$EDITOR"
export PATH="$HOME/bin:$PATH"

: