" Fuzzy finding with fzf.vim, on the fzf binary and Vim plugin that Fedora's fzf
" package installs onto Neovim's runtime path.
"
" The float takes its border from 'winborder', so --no-border cancels any border
" $FZF_DEFAULT_OPTS asks for instead of drawing a second one inside it.

let g:fzf_layout = { 'window': { 'width': 0.9, 'height': 0.8 } }
let g:fzf_vim = {
      \ 'preview_window': ['right,50%,<70(up,40%)', 'ctrl-/'],
      \ 'options': '--no-border',
      \ }
let g:fzf_colors = {
      \ 'fg': ['fg', 'NormalFloat'],
      \ 'bg': ['bg', 'NormalFloat'],
      \ 'query': ['fg', 'NormalFloat'],
      \ 'hl': ['fg', 'PmenuMatch'],
      \ 'fg+': ['fg', 'PmenuSel'],
      \ 'bg+': ['bg', 'PmenuSel'],
      \ 'hl+': ['fg', 'PmenuMatchSel'],
      \ 'gutter': ['bg', 'NormalFloat'],
      \ 'info': ['fg', 'Comment'],
      \ 'border': ['fg', 'FloatBorder'],
      \ 'prompt': ['fg', 'Title'],
      \ 'pointer': ['fg', 'CursorLineNr'],
      \ 'marker': ['fg', 'Keyword'],
      \ 'spinner': ['fg', 'Comment'],
      \ 'header': ['fg', 'Comment'],
      \ }

nnoremap <leader>ff <Cmd>Files<CR>
nnoremap <leader>fg <Cmd>GFiles<CR>
nnoremap <leader>fb <Cmd>Buffers<CR>
nnoremap <leader>fo <Cmd>History<CR>
nnoremap <leader>fr <Cmd>RG<CR>
nnoremap <leader>fw <Cmd>execute 'Rg' expand('<cword>')<CR>
nnoremap <leader>fl <Cmd>BLines<CR>
nnoremap <leader>fh <Cmd>Helptags<CR>
nnoremap <leader>f: <Cmd>History:<CR>
