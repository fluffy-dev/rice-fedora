" The dbui drawer: its <C-j> and <C-k> sibling jumps duplicate J and K, so those
" keys go back to split navigation.
nmap <buffer> <C-j> <Plug>(rice-navigate-down)
nmap <buffer> <C-k> <Plug>(rice-navigate-up)
