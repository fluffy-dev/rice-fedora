" <C-h> <C-j> <C-k> <C-l> move between splits, and on into the neighbouring tmux
" pane when Neovim has no split further in that direction.
"
" tmux passes these keys through whenever its active pane runs Neovim, so neither
" side needs a plugin. Outside tmux they only move between splits. The <Plug>
" names let buffers whose plugins claim these keys, netrw and dbui, take them back.

function! s:navigate(direction) abort
  let l:window = winnr()
  execute 'wincmd' a:direction
  if winnr() != l:window || empty($TMUX)
    return
  endif
  let l:target = empty($TMUX_PANE) ? [] : ['-t', $TMUX_PANE]
  call jobstart(['tmux', 'select-pane'] + l:target + ['-' . tr(a:direction, 'hjkl', 'LDUR')])
endfunction

nnoremap <Plug>(rice-navigate-left) <Cmd>call <SID>navigate('h')<CR>
nnoremap <Plug>(rice-navigate-down) <Cmd>call <SID>navigate('j')<CR>
nnoremap <Plug>(rice-navigate-up) <Cmd>call <SID>navigate('k')<CR>
nnoremap <Plug>(rice-navigate-right) <Cmd>call <SID>navigate('l')<CR>

nmap <C-h> <Plug>(rice-navigate-left)
nmap <C-j> <Plug>(rice-navigate-down)
nmap <C-k> <Plug>(rice-navigate-up)
nmap <C-l> <Plug>(rice-navigate-right)
