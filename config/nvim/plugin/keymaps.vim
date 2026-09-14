" Mappings that belong to no single plugin.
"
" Neovim 0.12 already maps LSP actions (grn gra grr gri grt grx gO K), diagnostics
" ([d ]d <C-w>d), commenting (gc gcc) and bracket pairs ([q ]q [b ]b), so none of
" those are repeated here. <leader>a belongs to Claude Code and <C-Space> to tmux.

" Neovim's default <C-l> clears the search highlight and refreshes diffs, but <C-l>
" moves between splits here, so <Esc> takes over both.
nnoremap <Esc> <Cmd>nohlsearch<Bar>diffupdate<CR>

xnoremap < <gv
xnoremap > >gv
