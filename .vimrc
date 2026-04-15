let data_dir = has('nvim') ? stdpath('data') . '/site' : '~/.vim'
if empty(glob(data_dir . '/autoload/plug.vim'))
  silent execute '!curl -fLo '.data_dir.'/autoload/plug.vim --create-dirs  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

" Install vim-plug if not found
if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
endif

" Run PlugInstall if there are missing plugins
autocmd VimEnter * if len(filter(values(g:plugs), '!isdirectory(v:val.dir)'))
  \| PlugInstall --sync | source $MYVIMRC
\| endif

" ==== Options ====

syntax on
filetype plugin on

set hlsearch
set autoread
autocmd FocusGained,BufEnter,CursorHold,CursorHoldI * checktime
set background=dark
set number
set showmatch
set incsearch
set hidden
set ruler
set wrap
set ignorecase
set smartcase

let g:auto_save = 1
let g:NERDCreateDefaultMappings = 0
let g:NERDTreeShowHidden = 1

let $FZF_DEFAULT_COMMAND = 'find -L . -name "*" -type f 2>/dev/null
			\ | grep -v -E "tmp\/|.gitmodules|.git\/|vendor\/|node_modules\/"
			\ | sed "s|^\./||"'
let $FZF_DEFAULT_OPTS = '--reverse'

command! -bang -nargs=* Rg
  \ call fzf#vim#grep(
  \   'rg --follow --column --line-number --no-heading --color=always --smart-case -- '.shellescape(<q-args>),
  \   1, fzf#vim#with_preview(), <bang>0)


let g:fzf_layout = { 'window': { 'width': 1, 'height': 0.6, 'relative': v:true, 'yoffset': 1.0 } }
let g:fzf_action = {
			\ 'ctrl-t': 'tab split',
			\ 'ctrl-i': 'split',
			\ 'ctrl-v': 'vsplit' }



" ==== Shortcuts ====


map <silent> <LocalLeader>nt :NERDTreeToggle<CR>
map <silent> <LocalLeader>nr :NERDTree<CR>
map <silent> <LocalLeader>nf :NERDTreeFind<CR>

map <Leader>cc <Plug>NERDCommenterToggle('n', 'Toggle')<CR>

map <silent> <C-p> :Files<CR>
map <silent> <C-e> :History<CR>
map <silent> <C-1> :NERDTreeToggle<CR>

call plug#begin()

Plug '907th/vim-auto-save'
Plug 'vim-airline/vim-airline'
Plug 'tomasr/molokai'
Plug 'mg979/vim-visual-multi'
Plug 'preservim/nerdtree'
Plug 'jlanzarotta/bufexplorer'
Plug 'StanAngeloff/php.vim'
Plug 'nordtheme/vim'
Plug 'preservim/nerdcommenter'
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
Plug 'ludovicchabant/vim-gutentags'

call plug#end()

" ==== ctags ====

let g:gutentags_cache_dir = expand('~/.cache/vim/ctags/')
let g:gutentags_generate_on_new = 1
let g:gutentags_generate_on_missing = 1
let g:gutentags_generate_on_write = 1
let g:gutentags_generate_on_empty_buffer = 0
let g:gutentags_ctags_extra_args = ['--tag-relative=yes', '--fields=+ailmnS']

colorscheme nord
highlight Visual cterm=reverse ctermbg=NONE
