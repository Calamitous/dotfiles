set nocompatible " Vundle required
filetype off " Vundle required

" set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()
" set rtp+=~/.fzf

" let Vundle manage Vundle, required
Plugin 'gmarik/Vundle.vim'

Plugin 'Lokaltog/vim-easymotion'
Plugin 'godlygeek/tabular'
" Plugin 'amirh/HTML-AutoCloseTag'
Plugin 'itchyny/lightline.vim'
Plugin 'jeetsukumaran/vim-buffergator'
" Plugin 'mhinz/vim-signify' " Maybe?
Plugin 'scrooloose/nerdcommenter'
Plugin 'scrooloose/nerdtree'
Plugin 'fatih/vim-go'
Plugin 'sheerun/vim-polyglot'
Plugin 'tpope/vim-commentary'
Plugin 'tpope/vim-fugitive'
Plugin 'tpope/vim-repeat'
Plugin 'tpope/vim-speeddating'
Plugin 'tpope/vim-surround'
Plugin 'elixir-editors/vim-elixir'
Plugin 'junegunn/fzf'
Plugin 'ledger/vim-ledger'

" Plugin 'ctrlpvim/ctrlp.vim'
" " Plugin 'elixir-lang/vim-elixir'
" Plugin 'elixir-editors/vim-elixir'
" Plugin 'elmcast/elm-vim'
" Plugin 'kchmck/vim-coffee-script'
" Plugin 'scrooloose/syntastic'
" Plugin 'tpope/vim-markdown'
" Plugin 'tpope/vim-rails'

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

let mapleader=' '

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
" set paste " Make paste handling rational

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
" colorscheme dracula
" colorscheme zenburn
" colorscheme railscasts
colorscheme elflord
" colorscheme solarized
" colorscheme industry

map <Leader>l :set background=light<CR>
map <Leader>d :set background=dark<CR>

" Fugitive
map <Leader>gb :Gblame<CR>
map <Leader>gs :Gstatus<CR>
map <Leader>gc :Gcommit<CR>
map <Leader>gp :Gpush<CR>

" Syntastic
" let g:syntastic_mode_map = { 'mode': 'active',
                            " \ 'active_filetypes': ['ruby', 'coffee', 'javascript', 'json'],
                            " \ 'passive_filetypes': ['html', 'handlebars'] }

" CoffeeWatch
set suffixesadd+=.coffee
map <Leader>cw :CoffeeWatch<CR>
map <Leader>cr :CoffeeRun<CR>

" NERDTree
map <Leader>e :NERDTreeFind<CR>
let NERDTreeShowBookmarks=1
let NERDTreeQuitOnOpen=1
let NERDTreeShowHidden=1

" Tabular
nmap <Leader>a= :Tabularize /=<CR>
vmap <Leader>a= :Tabularize /=<CR>
nmap <Leader>a> :Tabularize /=><CR>
vmap <Leader>a> :Tabularize /=><CR>
nmap <Leader>a<Bar> :Tabularize /<Bar><CR>
vmap <Leader>a<Bar> :Tabularize /<Bar><CR>
nmap <Leader>a: :Tabularize /:<CR>
vmap <Leader>a: :Tabularize /:<CR>
nmap <Leader>a, :Tabularize /,<CR>
vmap <Leader>a, :Tabularize /,<CR>

nmap <Leader>o :FZF<CR>

set noshowmode

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

scriptencoding utf-8
set encoding=utf-8

set guioptions-=m
set guioptions-=T
set guioptions-=r

if !has('gui_running')
  set t_Co=256
endif

set colorcolumn=81,121

set listchars=nbsp:×,trail:. " tab:>>,,eol:⏎
set nolist

" fzf
" This is the default extra key bindings
" let g:fzf_action = { 'ctrl-t': 'tab split', 'ctrl-x': 'split', 'ctrl-v': 'vsplit' }

" An action can be a reference to a function that processes selected lines
function! s:build_quickfix_list(lines)
  call setqflist(map(copy(a:lines), '{ "filename": v:val }'))
  copen
  cc
endfunction

" let g:fzf_action = { 'ctrl-q': function('s:build_quickfix_list'), 'ctrl-t': 'tab split', 'ctrl-x': 'split', 'ctrl-v': 'vsplit' }
let g:fzf_action = { 'ctrl-q': function('s:build_quickfix_list') }

" Default fzf layout
" - down / up / left / rig, 'ctrl-t': 'tab split', 'ctrl-x': 'split', 'ctrl-v': 'vsplit' ht
let g:fzf_layout = { 'down': '~60%' }

" You can set up fzf window using a Vim command (Neovim or latest Vim 8 required)
" let g:fzf_layout = { 'window': 'enew' }
" let g:fzf_layout = { 'window': '-tabnew' }
" let g:fzf_layout = { 'window': '10split enew' }

" Customize fzf colors to match your color scheme
let g:fzf_colors =
\ { 'fg':      ['fg', 'Normal'],
  \ 'bg':      ['bg', 'Normal'],
  \ 'hl':      ['fg', 'Comment'],
  \ 'fg+':     ['fg', 'CursorLine', 'CursorColumn', 'Normal'],
  \ 'bg+':     ['bg', 'CursorLine', 'CursorColumn'],
  \ 'hl+':     ['fg', 'Statement'],
  \ 'info':    ['fg', 'PreProc'],
  \ 'border':  ['fg', 'Ignore'],
  \ 'prompt':  ['fg', 'Conditional'],
  \ 'pointer': ['fg', 'Exception'],
  \ 'marker':  ['fg', 'Keyword'],
  \ 'spinner': ['fg', 'Label'],
  \ 'header':  ['fg', 'Comment'] }

" Enable per-command history.
" CTRL-N and CTRL-P will be automatically bound to next-history and
" previous-history instead of down and up. If you don't like the change,
" explicitly bind the keys to down and up in your $FZF_DEFAULT_OPTS.
let g:fzf_history_dir = '~/.local/share/fzf-history'

" Ripgrep *all* the things!
command! -bang -nargs=* Rg
  \ call fzf#vim#grep(
  \   'rg --column --line-number --no-heading --color=always --smart-case '.shellescape(<q-args>), 1,
  \   <bang>0)

" Files command with preview window
command! -bang -nargs=? -complete=dir Files
  \ call fzf#vim#files(<q-args>, fzf#vim#with_preview(), <bang>0)

command! Buffers call fzf#run(fzf#wrap(
    \ {'source': map(range(1, bufnr('$')), 'bufname(v:val)')}))

command! -bang Buffers call fzf#run(fzf#wrap(
    \ {'source': map(range(1, bufnr('$')), 'bufname(v:val)')}, <bang>0))

let g:lightline = {
      \ 'colorscheme': 'wombat',
      \ 'active': {
      \   'left': [ [ 'mode', 'paste' ],
      \             [ 'readonly', 'filename' ] ],
      \ },
      \ 'component_function': {
      \   'fileformat': 'LightlineFileformat',
      \   'filetype': 'LightlineFiletype',
      \   'filename': 'LightlineFilename',
      \ },
      \ }

function! LightlineFileformat()
  return winwidth(0) > 120 ? &fileformat : ''
endfunction

function! LightlineFiletype()
  return winwidth(0) > 120 ? (&filetype !=# '' ? &filetype : 'no ft') : ''
endfunction

function! LightlineFilename()
  let filename = expand('%:t') !=# '' ? expand('%:t') : '[No Name]'
  let modified = &modified ? ' +' : ''
  return filename . modified
endfunction

:inoremap kj <Esc>

func! WordProcessorMode()
  setlocal formatoptions=1
  setlocal noexpandtab
  map j gj
  map k gk
  setlocal spell spelllang=en_us
  set thesaurus+=~/.vim/thesaurus/mthesaur.txt
  set complete+=s
  set formatprg=par
  setlocal wrap
  setlocal linebreak

  set nonu
  " set textwidth=80
  " set wrap
  " set spell

  inoremap . .<C-g>u
  inoremap ! !<C-g>u
  inoremap ? ?<C-g>u
  inoremap : :<C-g>u

  set cpoptions+=J
  " colo default

  abbr dk D'khara
  abbr dks D'khara's
  abbr dkp D'khara.
  abbr dksp D'khara's.

  abbr drn Dr. Navarre
  abbr drnp Dr. Navarre
  abbr drns Dr. Navarre's

  abbr lim Little Timmy
  abbr lim Little Timmy

  abbr mmd Mrs. Meade
  abbr mmds Mrs. Meade's

  abbr bw Battle Wagon
  abbr bwc Battle Wagon,
  abbr bwp Battle Wagon.
  abbr vw Battle Wagon
  abbr vwc Battle Wagon,
  abbr vwp Battle Wagon.

  abbr rf Riotfish
  abbr ov Oliver
  abbr ovp Oliver.
  abbr dx Daugereaux
  abbr fl Fleer
endfu
com! WP call WordProcessorMode()

abbr srbc Pastor John Magas / Solid Rock Baptist Church
abbr cphe! Clay-Platte Home Educators (CPHE)

runtime macros/matchit.vim

" let g:polyglot_disabled = ['go']
abbr {} {<CR><Tab><CR>}
abbr errck if err != nil {<CR>return<CR>}
abbr swe software engineer
abbr SWE Software Engineer

let g:ledger_maxwidth = 100
let g:ledger_fuzzy_account_completion = 1
let g:ledger_align_at=76
let g:ledger_is_hledger = v:true
let g:ledger_default_commodity = '$'
