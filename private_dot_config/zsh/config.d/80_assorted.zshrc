# All the rest

# docker
alias dka="docker ps -q | xargs docker stop | xargs docker rm"
alias dka!="docker ps -aq | xargs docker stop | xargs docker rm"
alias dkav!="docker volume ls | xargs docker volume rm"
alias dk!="dka! && dkav!"

# sytemctl
alias ctl="sudo systemctl"
alias ctlx="sudo systemctl stop"
alias ctls="sudo systemctl start"
alias ctlr="sudo systemctl restart"
alias ctll="sudo journalctl -b -u"
ctlf () {
    sudo systemctl restart $1
    sudo journalctl -b -u $1
}

# telnet
alias telnetssl="openssl s_client -connect"

# qalc
alias calc="qalc -t"

# brew
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" > /dev/null

# kubernetes
source <(kubectl completion zsh) > /dev/null
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

# minikube
source <(minikube completion zsh) > /dev/null

# thefuck
eval $(thefuck --alias) > /dev/null

# terraform
complete -o nospace -C /usr/bin/terraform terraform > /dev/null

# ansible
export ANSIBLE_NOCOWS=1

# direnv
eval "$(direnv hook zsh)" > /dev/null

# bat
alias man="batman"

# ghc
[ -f "~/.ghcup/env" ] && source "~/.ghcup/env" > /dev/null

# deno
export DENO_INSTALL="/home/flo/.deno"
export PATH="$DENO_INSTALL/bin:$PATH"

# zsh
autoload -U +X bashcompinit > /dev/null
bashcompinit > /dev/null

# xclip
alias clip="xclip -selection clipboard"

# npm
npm-shasum() {
  npm view "$1" dist.integrity
}

# example: run_with_caps cap_net_admin "echo 'Hello, World!'"
run_with_caps() {
  # The last argument is the command to execute
  local command="${@: -1}"

  # Start building the capsh command with hardcoded capabilities
  cmd="sudo capsh --caps=\"cap_setpcap,cap_setuid,cap_setgid+ep\" --keep=1"

  # Loop through all arguments except the last one, which is the command
  for ((i=1; i<=$#-1; i++)); do
    local cap="${!i}"
    cmd+=" --caps=\"${cap}+eip\""
    cmd+=" --inh=\"${cap}\""
    cmd+=" --addamb=\"${cap}\""
  done

  # Append the command to execute
  cmd+=" -- -c \"${command}\""

  # Execute the command
  eval $cmd
}

alias psx="procs --color=always --sortd mem | fzf --ansi --height 12 --header-lines=2 --layout reverse | awk '{print $1}'"

# android
export ANDROID_HOME="$HOME/Android/Sdk"
export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin:$ANDROID_HOME/platform-tools:$PATH"
alias android="emulator -list-avds | sed '/^INFO/ d' | fzf --height 5 | xargs -I {} bash -c 'emulator -gpu host -avd {} > /dev/null 2>&1 &'"

# java
export PATH="/usr/lib/jvm/bellsoft-java21-amd64/bin:$PATH"

# azure
az-select-subscription() {
  az account list --output table | tail -n +3 | fzf --layout reverse --height 10 --header "Select Azure subscription" | awk '{print $(NF-3)}' | xargs -I {} az account set --subscription {}
}

: