" Managed by dotfiles/install.sh — overwritten on each install.
" Minimal vim config: built-in features only, no plugin manager.

set nocompatible
syntax on
filetype plugin indent on

" --- Display -----------------------------------------------------------------
set number relativenumber
set numberwidth=4
set cursorline
set signcolumn=yes
set scrolloff=8 sidescrolloff=8
set showcmd
set laststatus=2
set display=lastline
set belloff=all
set encoding=utf-8
set fileencoding=utf-8

" --- Theming -----------------------------------------------------------------
if has('termguicolors')
  set termguicolors
endif
set background=dark
silent! colorscheme habamax
if !exists('g:colors_name')
  silent! colorscheme slate
endif

" --- Editor UX ---------------------------------------------------------------
set mouse=a
set hidden
set lazyredraw
set updatetime=300
set timeoutlen=500
set ttimeoutlen=10
set splitright splitbelow
set backspace=indent,eol,start
set autoread
if has('clipboard')
  set clipboard^=unnamed,unnamedplus
endif

" --- Indentation -------------------------------------------------------------
set expandtab
set tabstop=4 softtabstop=4 shiftwidth=4
set shiftround
set smartindent autoindent

augroup dotfiles_indent
  autocmd!
  autocmd FileType yaml,json,html,css,javascript,typescript,lua,vim,sh,zsh,bash
        \ setlocal tabstop=2 softtabstop=2 shiftwidth=2
augroup END

" --- Search ------------------------------------------------------------------
set incsearch hlsearch
set ignorecase smartcase

" --- Wildmenu / completion ---------------------------------------------------
set wildmenu
set wildmode=longest:full,full
set wildignorecase
set wildignore+=*.o,*.obj,*.pyc,*.class,*.swp,*.bak,*~
set wildignore+=.git/*,node_modules/*,*.DS_Store

" --- Persistence -------------------------------------------------------------
set noswapfile nobackup nowritebackup
set undofile
let s:undodir = expand('~/.vim/undo')
if !isdirectory(s:undodir)
  silent! call mkdir(s:undodir, 'p', 0700)
endif
let &undodir = s:undodir

" --- Statusline --------------------------------------------------------------
set statusline=
set statusline+=\ %f
set statusline+=\ %m%r
set statusline+=%=
set statusline+=\ %y
set statusline+=\ \|\ %{&fileencoding?&fileencoding:&encoding}
set statusline+=\ \|\ %l:%c
set statusline+=\ \|\ %p%%\ 

" --- Auto-resize splits on terminal resize -----------------------------------
augroup dotfiles_resize
  autocmd!
  autocmd VimResized * wincmd =
augroup END

" --- Mappings ----------------------------------------------------------------
let mapleader = ' '
let maplocalleader = ' '

" Leader maps
nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>
nnoremap <leader>h :nohlsearch<CR>
nnoremap <leader>r :source $MYVIMRC<CR>

" Window navigation (matches tmux bindings)
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" Visual indent keeps selection
vnoremap < <gv
vnoremap > >gv

" Y yanks to end of line (consistent with D, C)
nnoremap Y y$

" Move by display lines when wrapped
nnoremap j gj
nnoremap k gk
vnoremap j gj
vnoremap k gk

" jk exits insert mode
inoremap jk <Esc>
