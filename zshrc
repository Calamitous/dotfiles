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

export TERM='xterm-256color'
# setxkbmap -option caps:escape

autoload -U compinit && compinit
zmodload -i zsh/complist

fpath=(/usr/local/share/zsh-completions $fpath)

export HISTFILE=~/.zsh_history

export LEDGER_FILE=~/Projects/personal_finances/hledger.journal

bindkey "^R" history-incremental-search-backward

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

export FZF_DEFAULT_COMMAND='rg --files --no-ignore --hidden --follow --glob "!.git/*"'
