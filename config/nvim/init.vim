" Neovim entry point: leader, core options and the plugin list.
"
" Everything else sits where Neovim finds it unaided: plugin/ holds one file per
" concern, after/ftplugin/ the per-language settings, colors/ the colorscheme.
" Without vim-plug the plugin block is skipped and the rest still loads.

let mapleader = "\<Space>"

" No remote plugins are used, and probing for their hosts costs startup time.
let g:loaded_python3_provider = 0
let g:loaded_node_provider = 0
let g:loaded_perl_provider = 0
let g:loaded_ruby_provider = 0

set number relativenumber
set signcolumn=yes
set cursorline
set scrolloff=8 sidescrolloff=8
set nowrap
set splitright splitbelow
set ignorecase smartcase
set inccommand=split
set virtualedit=block
set undofile
" Neovim picks wl-copy and wl-paste by itself when $WAYLAND_DISPLAY is set.
set clipboard=unnamedplus
set updatetime=250
set timeoutlen=500
set expandtab shiftwidth=4 softtabstop=-1
set list
let &listchars = 'tab:» ,trail:·,nbsp:␣'
let &fillchars = 'eob: '
set laststatus=3 noshowmode
set winborder=rounded
set foldlevelstart=99 foldtext=
set shortmess+=Ic
" Normal-mode commands keep working while the Russian layout is active: each
" JCUKEN key stands for the QWERTY key in the same position.
let &langmap = 'ёйцукенгшщзхъфывапролджэячсмитьбю;`qwertyuiop[]asdfghjkl\;''zxcvbnm\,.,'
      \ . 'ЁЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮ;~QWERTYUIOP{}ASDFGHJKL:"ZXCVBNM<>'
set nolangremap

if filereadable(stdpath('data') . '/site/autoload/plug.vim')
  call plug#begin()
  Plug 'neovim/nvim-lspconfig'
  Plug 'nvim-treesitter/nvim-treesitter', { 'branch': 'main', 'do': ':TSUpdate' }
  Plug 'junegunn/fzf.vim'
  Plug 'tpope/vim-fugitive'
  Plug 'airblade/vim-gitgutter'
  Plug 'tpope/vim-surround'
  Plug 'tpope/vim-repeat'
  Plug 'tpope/vim-sleuth'
  Plug 'tpope/vim-dadbod'
  Plug 'kristijanhusak/vim-dadbod-ui', { 'on': ['DBUI', 'DBUIToggle', 'DBUIAddConnection', 'DBUIFindBuffer'] }
  Plug 'kristijanhusak/vim-dadbod-completion'
  call plug#end()
endif

colorscheme rice
