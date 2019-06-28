```
Maybe: https://github.com/junegunn/fzf#using-homebrew-or-linuxbrew
wget https://packages.erlang-solutions.com/erlang-solutions_1.0_all.deb && sudo dpkg -i erlang-solutions_1.0_all.deb

# ALL
sudo apt-get install build-essential vim zsh git tmux xmlstarlet jq openssh-server links ncurses-term

#LANGS
sudo apt-get install cmake postgresql erlang python-dev nodejs npm elixir sqlite3

# GRAPHICAL
sudo apt-get install i3 dmenu vim-gnome

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
mkdir ~/.i3
ln -s ~/Projects/dotfiles/i3config ~/.i3/config
ln -s ~/Projects/dotfiles/i3status.conf ~/.i3status.conf
ln -s ~/Projects/dotfiles/muttrc ~/.muttrc

touch ~/.private.conf

# Vundle install
git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
vim +PluginInstall +qall
cd ~/.vim/bundle/YouCompleteMe/
./install.py

git clone git://github.com/altercation/vim-colors-solarized.git ~/.vim/bundle/vim-colors-solarized

sudo gem install grep-fu

sudo dpkg -i ./<file>
```
