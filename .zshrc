#
# Executes commands at the start of an interactive session.
#
# Authors:
#   Sorin Ionescu <sorin.ionescu@gmail.com>
#

# Source Prezto.
if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi

# Customize to your needs...
eval "$(rbenv init - zsh --no-rehash)"
source ~/.nvm/nvm.sh
unsetopt AUTO_CD

export AWS_ACCESS_KEY_ID=AKIAJ53WMSACZHHZWVPA
export AWS_SECRET_ACCESS_KEY=B1zEtHOjEhOrZJuCmFfroWZvvZ98BG+1k68oeKY9
export EDITOR=vim
export PATH=$PATH:~/Projects/grep-fu/bin
export PATH=/opt/local/bin:/opt/local/sbin:$PATH
export PATH=$PATH:/Users/ericbudd/.rbenv/versions/2.2.0/lib/ruby/gems/2.2.0/gems/tmuxinator-0.6.10/bin

# Turn off the stupid autocorrect malfeature
unsetopt correct
source ~/.zsh_aliases
# This seems to work regardless?
# source ~/.bin/tmuxinator.zsh

bindkey "^A" beginning-of-line
bindkey "^E" end-of-line
bindkey "^X^E" edit-command-line
