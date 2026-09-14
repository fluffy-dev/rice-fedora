" Hurl buffers: run the request under the cursor, with its headers, or every
" request in the file.
nnoremap <buffer> <leader>rr <Cmd>HurlRunEntry<CR>
nnoremap <buffer> <leader>ri <Cmd>HurlRunEntry!<CR>
nnoremap <buffer> <leader>rf <Cmd>HurlRun<CR>
" No space before a bar: it would become part of the mapping being removed.
let b:undo_ftplugin = (exists('b:undo_ftplugin') ? b:undo_ftplugin . ' | ' : '')
      \ . 'silent! nunmap <buffer> <leader>rr| silent! nunmap <buffer> <leader>ri| silent! nunmap <buffer> <leader>rf'
