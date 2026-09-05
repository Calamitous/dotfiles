# Source Prezto.
zstyle 'prompt' theme 'damoekri'

unsetopt AUTO_CD

source ~/.private.conf

export EDITOR=vim
export VISUAL=vim

# export PATH=$PATH:~/Projects/grep-fu/bin
export PATH=/opt/local/bin:/opt/local/sbin:$PATH
export PATH=~/.local/bin:$PATH
export PATH=~/bin:$PATH
export PATH=~/.emacs.d/bin:$PATH
export PATH=/usr/local/go/bin:$PATH
# export PATH=$PATH:/Users/ericbudd/.rbenv/versions/2.2.0/lib/ruby/gems/2.2.0/gems/tmuxinator-0.6.10/bin

# Turn off the stupid autocorrect malfeature
unsetopt correct
# unalias rm
source ~/.zsh_aliases
# This seems to work regardless?
# source ~/.bin/tmuxinator.zsh

bindkey "^A" beginning-of-line
bindkey "^E" end-of-line
bindkey "^X^E" edit-command-line

if [[ -z "$TMUX" ]]; then
  export TERM='xterm-256color'
fi

# setxkbmap -option caps:escape


# fpath=(/usr/local/share/zsh-completions $fpath)

export HISTFILE=~/.zsh_history
export SAVEHIST=100

# export LEDGER_FILE=~/Projects/personal_finances/hledger.journal

bindkey "^R" history-incremental-search-backward

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

export FZF_DEFAULT_COMMAND='rg --files --no-ignore --hidden --follow --glob "!.git/*"'

# export GOPATH=$HOME/golang
# export GOROOT=/usr/local/opt/go/libexec
export PATH=$PATH:$GOPATH/bin
# export PATH=$PATH:$GOROOT/bin
export PATH="$PATH:/usr/local/protobuf/bin"

# . "$HOME/.asdf/asdf.sh"

# append completions to fpath
fpath=(${ASDF_DIR}/completions $fpath)

zmodload -i zsh/complist

fpath=(/usr/local/share/zsh-completions $fpath)

# Highlight the current autocomplete option
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# Fix SSH Config Host Autocomplete on macos
zstyle ':completion:*:(s|ssh|scp|ftp|sftp):*' hosts $hosts
zstyle ':completion:*:(s|ssh|scp|ftp|sftp):*' users $users

# Allow for autocomplete to be case insensitive
zstyle ':completion:*' matcher-list '' 'm:{[:lower:][:upper:]}={[:upper:][:lower:]}' '+l:|?=** r:|?=**'

# Initialize the autocompletion
# export FZF_DEFAULT_COMMAND='rg --files --no-ignore --hidden --follow --glob "!.git/*"'
# . $HOME/.asdf/asdf.sh
# append completions to fpath
# fpath=(${ASDF_DIR}/completions $fpath)
# initialise completions with ZSH's compinit
# compinit must come AFTER every fpath change above, or the added
# completion directories are invisible to it.
autoload -Uz compinit && compinit

# Manjaro-supplied
# # Use powerline
# USE_POWERLINE="true"
# # Source manjaro-zsh-configuration
# if [[ -e /usr/share/zsh/manjaro-zsh-config ]]; then
#   source /usr/share/zsh/manjaro-zsh-config
# fi
# # Use manjaro zsh prompt
# if [[ -e /usr/share/zsh/manjaro-zsh-prompt ]]; then
#   source /usr/share/zsh/manjaro-zsh-prompt
# fi

h=()
if [[ -r ~/.ssh/config ]]; then
  h=($h ${${${(@M)${(f)"$(cat ~/.ssh/config)"}:#Host *}#Host }:#*[*?]*})
fi
if [[ -r ~/.ssh/known_hosts ]]; then
  h=($h ${${${(f)"$(cat ~/.ssh/known_hosts{,2} || true)"}%%\ *}%%,*}) 2>/dev/null
fi
if [[ $#h -gt 0 ]]; then
  zstyle ':completion:*:ssh:*' hosts $h
  zstyle ':completion:*:slogin:*' hosts $h
fi
. /opt/asdf-vm/asdf.sh

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# grok
# export PATH=/home/eric/.grok/bin:$PATH

export DISPLAY=:0
