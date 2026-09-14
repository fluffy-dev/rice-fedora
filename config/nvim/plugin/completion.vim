" Native as-you-type completion, without a completion plugin.
"
" 'autocomplete' (new in Neovim 0.12) opens the menu while typing, fed by the
" sources in 'complete': the omnifunc first, which language servers and
" vim-dadbod-completion provide, then words from this buffer, other windows and
" other buffers. <C-n> and <C-p> move, <C-y> accepts, and accepting an LSP item
" also applies its auto-import.

set autocomplete
set completeopt=menuone,noselect,popup,fuzzy
set complete=o,.^10,w^5,b^5
set pumheight=12
