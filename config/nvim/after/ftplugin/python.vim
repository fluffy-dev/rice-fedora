" Python buffers: a guide at ruff's default line length, and :make type-checks
" the whole project with basedpyright, which the language server only does for
" open files.
setlocal colorcolumn=89
let b:pyright_makeprg = 'basedpyright'
compiler pyright
let b:undo_ftplugin = (exists('b:undo_ftplugin') ? b:undo_ftplugin . ' | ' : '')
      \ . 'setlocal colorcolumn< makeprg< errorformat< | unlet! b:pyright_makeprg b:current_compiler'
