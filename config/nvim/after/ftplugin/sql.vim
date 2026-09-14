" SQL buffers: completion from the connected database, and statements run in place.
"
" <leader>de runs the paragraph under the cursor, or the selection, against the
" first of b:db, $DATABASE_URL and g:db that dadbod finds.
setlocal shiftwidth=2
let b:undo_ftplugin = (exists('b:undo_ftplugin') ? b:undo_ftplugin . ' | ' : '') . 'setlocal shiftwidth<'

if exists('g:vim_dadbod_completion_loaded')
  setlocal omnifunc=vim_dadbod_completion#omni complete=o,.^10
  let b:undo_ftplugin .= ' omnifunc< complete<'
endif

nnoremap <buffer> <leader>de vip:DB<CR>
xnoremap <buffer> <leader>de :DB<CR>
" No space before a bar: it would become part of the mapping being removed.
let b:undo_ftplugin .= ' | silent! nunmap <buffer> <leader>de| silent! xunmap <buffer> <leader>de'
