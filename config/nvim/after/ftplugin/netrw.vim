" netrw buffers: netrw binds <C-h> and <C-l> to its hiding list and refresh, so
" they go back to split navigation and refresh moves to <F5>.
nmap <buffer> <C-h> <Plug>(rice-navigate-left)
nmap <buffer> <C-l> <Plug>(rice-navigate-right)
nmap <buffer> <F5> <Plug>NetrwRefresh
