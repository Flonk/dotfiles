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

:
