" Databases through vim-dadbod, its drawer and its completion source.
"
" Connections come from $DATABASE_URL, which direnv usually sets per project, or
" from g:dbs. Keep passwords in ~/.pgpass rather than in a URL: the drawer saves
" connections added with :DBUIAddConnection as plain text.

let g:db_ui_env_variable_url = 'DATABASE_URL'
let g:db_ui_use_nerd_fonts = 1
let g:db_ui_winwidth = 36

" The runtime sql ftplugin maps a dozen insert-mode keys behind <C-c>, which
" makes <C-c> wait for a second key before it leaves insert mode.
let g:omni_sql_no_default_maps = 1

nnoremap <leader>du <Cmd>DBUIToggle<CR>
nnoremap <leader>df <Cmd>DBUIFindBuffer<CR>
nnoremap <leader>dc <Cmd>DBUIAddConnection<CR>
