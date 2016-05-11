```
wget https://packages.erlang-solutions.com/erlang-solutions_1.0_all.deb && sudo dpkg -i erlang-solutions_1.0_all.deb

sudo apt-get install build-essential cmake postgresql erlang git vim xmonad dmenu zsh python-dev tmux nodejs npm elixir vim-gnome ncurses-term openssh-server powerline

git clone --recursive https://github.com/sorin-ionescu/prezto.git "${ZDOTDIR:-$HOME}/.zprezto"

setopt EXTENDED_GLOB
for rcfile in "${ZDOTDIR:-$HOME}"/.zprezto/runcoms/^README.md(.N); do
  ln -s "$rcfile" "${ZDOTDIR:-$HOME}/.${rcfile:t}"
done

chsh -s $(which zsh)

mkdir Projects
cd Projects
git clone git@github.com:Calamitous/dotfiles.git
ln -s /home/eric/Projects/dotfiles/ /home/eric/.

ln -s /home/eric/Projects/dotfiles/gitconfig /home/eric/.gitconfig
ln -s /home/eric/Projects/dotfiles/jshintrc /home/eric/.jshintrc
ln -s /home/eric/Projects/dotfiles/tmux.conf /home/eric/.tmux.conf
ln -s /home/eric/Projects/dotfiles/tmuxinator /home/eric/.tmuxinator
ln -s /home/eric/Projects/dotfiles/vimrc /home/eric/.vimrc
ln -s /home/eric/Projects/dotfiles/zsh_aliases /home/eric/.zsh_aliases
ln -s /home/eric/Projects/dotfiles/zshrc /home/eric/.zshrc
ln -s /home/eric/Projects/dotfiles/zpreztorc /home/eric/.zpreztorc

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
