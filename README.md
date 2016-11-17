```
wget https://packages.erlang-solutions.com/erlang-solutions_1.0_all.deb && sudo dpkg -i erlang-solutions_1.0_all.deb

sudo apt-get install build-essential cmake postgresql erlang git vim xmonad dmenu zsh python-dev tmux nodejs npm elixir vim-gnome ncurses-term openssh-server powerline sqlite3 links

git clone --recursive https://github.com/sorin-ionescu/prezto.git "${ZDOTDIR:-$HOME}/.zprezto"

setopt EXTENDED_GLOB
for rcfile in "${ZDOTDIR:-$HOME}"/.zprezto/runcoms/^README.md(.N); do
  ln -s "$rcfile" "${ZDOTDIR:-$HOME}/.${rcfile:t}"
done

chsh -s $(which zsh)

mkdir Projects
cd Projects
git clone git@github.com:Calamitous/dotfiles.git
ln -s ~/Projects/dotfiles/ ~/.

ln -s ~/Projects/dotfiles/gitconfig ~/.gitconfig
ln -s ~/Projects/dotfiles/jshintrc ~/.jshintrc
ln -s ~/Projects/dotfiles/tmux.conf ~/.tmux.conf
ln -s ~/Projects/dotfiles/tmuxinator ~/.tmuxinator
ln -s ~/Projects/dotfiles/vimrc ~/.vimrc
ln -s ~/Projects/dotfiles/zsh_aliases ~/.zsh_aliases
ln -s ~/Projects/dotfiles/zshrc ~/.zshrc
ln -s ~/Projects/dotfiles/zpreztorc ~/.zpreztorc

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
