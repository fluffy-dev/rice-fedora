" Git in the editor: fugitive for status, blame and diffs, gitgutter for hunks.
"
" Both run git only as short-lived jobs, paced by 'updatetime', and keep no
" process alive. The gutter uses thin bars so it reads as a margin, not as text.

let g:gitgutter_map_keys = 0
let g:gitgutter_sign_added = '▎'
let g:gitgutter_sign_modified = '▎'
let g:gitgutter_sign_removed = '▁'
let g:gitgutter_sign_removed_first_line = '▔'
let g:gitgutter_sign_modified_removed = '▎'

nmap ]h <Plug>(GitGutterNextHunk)
nmap [h <Plug>(GitGutterPrevHunk)
nmap <leader>hs <Plug>(GitGutterStageHunk)
xmap <leader>hs <Plug>(GitGutterStageHunk)
nmap <leader>hu <Plug>(GitGutterUndoHunk)
nmap <leader>hp <Plug>(GitGutterPreviewHunk)
omap ih <Plug>(GitGutterTextObjectInnerPending)
omap ah <Plug>(GitGutterTextObjectOuterPending)
xmap ih <Plug>(GitGutterTextObjectInnerVisual)
xmap ah <Plug>(GitGutterTextObjectOuterVisual)

nnoremap <leader>gg <Cmd>Git<CR>
nnoremap <leader>gb <Cmd>Git blame<CR>
nnoremap <leader>gd <Cmd>Gvdiffsplit<CR>
nnoremap <leader>gw <Cmd>Gwrite<CR>
nnoremap <leader>gl <Cmd>BCommits<CR>
