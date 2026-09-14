" netrw as a quiet file browser, opened on the current file's directory with -.
"
" g:netrw_altfile makes <C-^> return to the file netrw was opened from rather
" than to the listing.

let g:netrw_banner = 0
let g:netrw_altfile = 1
let g:netrw_preview = 1
let g:netrw_sort_sequence = '[\/]$,*'

nnoremap - <Cmd>Explore<CR>
