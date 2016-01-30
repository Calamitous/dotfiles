```
wget https://packages.erlang-solutions.com/erlang-solutions_1.0_all.deb && sudo dpkg -i erlang-solutions_1.0_all.deb

sudo apt-get install build-essential cmake postgresql erlang git vim xmonad dmenu zsh python-dev tmux nodejs npm elixir vim-gnome ncurses-term openssh-server

git clone --recursive https://github.com/sorin-ionescu/prezto.git "${ZDOTDIR:-$HOME}/.zprezto"

setopt EXTENDED_GLOB
for rcfile in "${ZDOTDIR:-$HOME}"/.zprezto/runcoms/^README.md(.N); do
  ln -s "$rcfile" "${ZDOTDIR:-$HOME}/.${rcfile:t}"
done

chsh -s $(which zsh)

mkdir Projects
cd Projects
git clone git@github.com:Calamitous/dotfiles.git
ln -s /home/ericbudd/Projects/dotfiles/ /home/ericbudd/.

ln -s /home/ericbudd/Projects/dotfiles/gitconfig /home/ericbudd/.gitconfig
ln -s /home/ericbudd/Projects/dotfiles/jshintrc /home/ericbudd/.jshintrc
ln -s /home/ericbudd/Projects/dotfiles/tmux.conf /home/ericbudd/.tmux.conf
ln -s /home/ericbudd/Projects/dotfiles/tmuxinator /home/ericbudd/.tmuxinator
ln -s /home/ericbudd/Projects/dotfiles/vimrc /home/ericbudd/.vimrc
ln -s /home/ericbudd/Projects/dotfiles/zsh_aliases /home/ericbudd/.zsh_aliases
ln -s /home/ericbudd/Projects/dotfiles/zshrc /home/ericbudd/.zshrc

touch ~/.private_conf

# Vundle install
git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
vim +PluginInstall +qall
cd ~/.vim/bundle/YouCompleteMe/
./install.py

git clone git://github.com/altercation/vim-colors-solarized.git ~/.vim/bundle/vim-colors-solarized

sudo gem install grep-fu

sudo dpkg -i ./<file>
```
