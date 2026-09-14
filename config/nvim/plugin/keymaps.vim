" Mappings that belong to no single plugin.
"
" Neovim 0.12 already maps LSP actions (grn gra grr gri grt grx gO K), diagnostics
" ([d ]d <C-w>d), commenting (gc gcc) and bracket pairs ([q ]q [b ]b), so none of
" those are repeated here. <leader>a belongs to Claude Code and <C-Space> to tmux.

" <C-l> clears the search highlight by default, but it moves between splits here.
nnoremap <Esc> <Cmd>nohlsearch<CR>

xnoremap < <gv
xnoremap > >gv
