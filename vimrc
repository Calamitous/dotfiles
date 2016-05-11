set nocompatible " Vundle required
filetype off " Vundle required

" set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

" let Vundle manage Vundle, required
Plugin 'gmarik/Vundle.vim'

Plugin 'tpope/vim-fugitive'
Plugin 'ctrlpvim/ctrlp.vim'
Plugin 'scrooloose/nerdtree'
Plugin 'scrooloose/nerdcommenter'
Plugin 'Lokaltog/vim-easymotion'
Plugin 'godlygeek/tabular'
Plugin 'tpope/vim-surround'
Plugin 'altercation/vim-colors-solarized'
Plugin 'vim-airline/vim-airline'
Plugin 'vim-airline/vim-airline-themes'
Plugin 'jeetsukumaran/vim-buffergator'
Plugin 'scrooloose/syntastic'
Plugin 'mhinz/vim-signify'
Plugin 'groenewege/vim-less'
Plugin 'pangloss/vim-javascript'
Plugin 'kchmck/vim-coffee-script'
Plugin 'tpope/vim-rails'
Plugin 'tpope/vim-markdown'
Plugin 'digitaltoad/vim-jade.git'
Plugin 'tpope/vim-haml'
Plugin 'amirh/HTML-AutoCloseTag'
Plugin 'hail2u/vim-css3-syntax'
Plugin 'edkolev/tmuxline.vim'
Plugin 'vim-scripts/dbext.vim'
Plugin 'aquach/vim-http-client'
Plugin 'Valloric/YouCompleteMe'
Plugin 'elixir-lang/vim-elixir'

" All of your Plugins must be added before the following line
call vundle#end()            " required
filetype plugin indent on    " required
" Brief help
" :PluginList       - lists configured plugins
" :PluginInstall    - installs plugins; append `!` to update or just :PluginUpdate
" :PluginSearch foo - searches for foo; append `!` to refresh local cache
" :PluginClean      - confirms removal of unused plugins; append `!` to auto-approve removal
"
" see :h vundle for more details or wiki for FAQ
" Put your non-Plugin stuff after this line

let mapleader=','

" Autoindent with two spaces, always expand tabs
set tabstop=2
set shiftwidth=2
set softtabstop=2
set expandtab
set autoindent

set cursorline " Highlight the current line
set number " Who doesn't want line numbers?
set backspace=indent,eol,start
set history=1000
highlight clear SignColumn " Don't highlight left columns
highlight clear LineNr

set showmatch " Highlight match braces
set incsearch " Search as you type
set ignorecase " Case insensitive search
set smartcase " ...except when we put a cap in there
set scrolloff=5 " Minimum lines above/below cursor
set nowrap " Don't wrap long lines
set paste " Make paste handling rational

" Remove trailing whitespace on save
function! <SID>StripTrailingWhitespaces()
  let _s=@/
  let l=line(".")
  let c=col(".")
  %s/\s\+$//e
  let @/=_s
  call cursor(l,c)
endfunction
autocmd BufWritePre * :call <SID>StripTrailingWhitespaces()

" Integrate with the clipboard if we have one
if has ('clipboard')
  if has ('unnamedplus')
    set clipboard=unnamed,unnamedplus
  else
    set clipboard=unnamed
  endif
endif

" Solarized
syntax enable
set background=dark
colorscheme solarized
" Let us switch from Solarized light to dark and back.
map <Leader>l :set background=light<CR>
map <Leader>d :set background=dark<CR>

" Fugitive
map <Leader>gs :Gstatus<CR>
map <Leader>gc :Gcommit<CR>
map <Leader>gp :Gpush<CR>

" Syntastic
let g:syntastic_mode_map = { 'mode': 'active',
                            \ 'active_filetypes': ['ruby', 'coffee', 'javascript', 'json'],
                            \ 'passive_filetypes': ['html', 'handlebars'] }

" CoffeeWatch
set suffixesadd+=.coffee
map <Leader>cw :CoffeeWatch<CR>
map <Leader>cr :CoffeeRun<CR>

" NERDTree
map <Leader>e :NERDTreeFind<CR>
let NERDTreeShowBookmarks=1
let NERDTreeQuitOnOpen=1
let NERDTreeShowHidden=1

" Airline
set laststatus=2 " Make airline show up at start.
let g:airline_powerline_fonts=1
let g:airline_theme='solarized'
let g:airline#extensions#branch#enabled=1

" Tabular
nmap <Leader>a= :Tabularize /=<CR>
vmap <Leader>a= :Tabularize /=<CR>
nmap <Leader>a<Bar> :Tabularize /<Bar><CR>
vmap <Leader>a<Bar> :Tabularize /<Bar><CR>
nmap <Leader>a: :Tabularize /:<CR>
vmap <Leader>a: :Tabularize /:<CR>
nmap <Leader>a, :Tabularize /,<CR>
vmap <Leader>a, :Tabularize /,<CR>

" ctrlp
let g:ctrlp_user_command=['.git/', 'cd %s && git ls-files --exclude-standard -co']
let g:ctrlp_extensions=['tag', 'buffertag', 'quickfix', 'line', 'changes']
let g:ctrlp_custom_ignore={
  \ 'dir': '(node_modules)|(\v[\/]\.(git|hg|svn)$)'
  \ }

" buffergator
let g:buffergator_sort_regime='mru'

" Instead of reverting the cursor to the last position in the buffer, we
" set it to the first line when editing a git commit message
au FileType gitcommit au! BufEnter COMMIT_EDITMSG call setpos('.', [0, 1, 1, 0])
" http://vim.wikia.com/wiki/Restore_cursor_to_file_position_in_previous_editing_session
" Restore cursor to file position in previous editing session
function! ResCur()
  if line("'\"") <= line("$")
    normal! g`"
    return 1
  endif
endfunction
augroup resCur
  autocmd!
  autocmd BufWinEnter * call ResCur()
augroup END

" dbext
let g:dbext_default_type = 'PGSQL'
let g:dbext_default_profile_Local_N360 = 'type=PGSQL:host=localhost:dbname=network360_development'
let g:dbext_default_profile_Local_Provider_Nexus = 'type=PGSQL:host=localhost:dbname=provider_nexus'
let g:dbext_default_profile_Local_Provider_Nexus_Test = 'type=PGSQL:host=localhost:dbname=provider_nexus_test'
let g:dbext_default_profile = 'Local_Provider_Nexus_Test'

" -- results buffer
let g:dbext_default_buffer_lines          = 20
let g:dbext_default_use_sep_result_buffer = 1
let g:dbext_display_command_line          = 1

" -- misc config
let g:dbext_default_always_prompt_for_variables = -1 " never prompt for variables

" set up autocompletion for SQL
autocmd FileType sql set omnifunc=sqlcomplete#Complete
autocmd FileType pgsql set omnifunc=sqlcomplete#Complete

" set file type for Postgres for SQL files
au BufNewFile,BufRead *.sql set ft=pgsql

" File layouts
set noswapfile
set backup
set undofile
set undolevels=1000
set undoreload=10000

function! InitializeDirectories()
  let parent = $HOME . '/.vim/'
  let dir_list = {
              \ 'backup': 'backupdir',
              \ 'views': 'viewdir',
              \ 'undo': 'undodir' }

  let common_dir = parent . '/'

  for [dirname, settingname] in items(dir_list)
    let directory = common_dir . dirname . '/'
    if exists("*mkdir")
      if !isdirectory(directory)
        call mkdir(directory)
      endif
    endif
    if !isdirectory(directory)
      echo "Warning: Unable to create backup directory: " . directory
      echo "Try: mkdir -p " . directory
    else
      let directory = substitute(directory, " ", "\\\\ ", "g")
      exec "set " . settingname . "=" . directory
    endif
  endfor
endfunction
call InitializeDirectories()
