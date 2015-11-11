# Source Prezto.
if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi
zstyle 'prompt' theme 'damoekri'

# eval "$(rbenv init - zsh --no-rehash)"
# source ~/.nvm/nvm.sh
unsetopt AUTO_CD

source ~/.private_conf

export EDITOR=vim
export VISUAL=vim

# export PATH=$PATH:~/Projects/grep-fu/bin
export PATH=/opt/local/bin:/opt/local/sbin:$PATH
# export PATH=$PATH:/Users/ericbudd/.rbenv/versions/2.2.0/lib/ruby/gems/2.2.0/gems/tmuxinator-0.6.10/bin

# Turn off the stupid autocorrect malfeature
unsetopt correct
source ~/.zsh_aliases
# This seems to work regardless?
# source ~/.bin/tmuxinator.zsh

bindkey "^A" beginning-of-line
bindkey "^E" end-of-line
bindkey "^X^E" edit-command-line

export TERM=xterm-256color
