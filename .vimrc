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

set hlsearch
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

" ==== Shortcuts ====


map <silent> <LocalLeader>nt :NERDTreeToggle<CR>
map <silent> <LocalLeader>nr :NERDTree<CR>
map <silent> <LocalLeader>nf :NERDTreeFind<CR>

call plug#begin()

Plug 'vim-scripts/vim-auto-save'
Plug 'vim-airline/vim-airline'
Plug 'tomasr/molokai'
Plug 'terryma/vim-multiple-cursors'
Plug 'preservim/nerdtree'
Plug 'jlanzarotta/bufexplorer'
Plug 'itchyny/lightline.vim'
Plug 'StanAngeloff/php.vim'
Plug 'arcticicestudio/nord-vim'
Plug 'preservim/nerdcommenter'

call plug#end()

colorscheme nord
highlight Visual cterm=reverse ctermbg=NONE
