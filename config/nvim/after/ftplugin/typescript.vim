" TypeScript buffers, TSX included through the runtime typescriptreact ftplugin:
" two-space indentation for new files, and :make type-checks the project with its
" own tsc when node_modules has one.
setlocal shiftwidth=2
let b:tsc_makeprg = (executable('node_modules/.bin/tsc') ? 'node_modules/.bin/tsc' : 'tsc')
      \ . ' --noEmit --pretty false'
compiler tsc
let b:undo_ftplugin = (exists('b:undo_ftplugin') ? b:undo_ftplugin . ' | ' : '')
      \ . 'setlocal shiftwidth< makeprg< errorformat< | unlet! b:tsc_makeprg b:current_compiler'
