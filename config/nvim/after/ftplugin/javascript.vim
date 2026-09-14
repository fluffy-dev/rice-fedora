" JavaScript buffers, JSX included through the runtime javascriptreact ftplugin:
" two-space indentation for new files.
setlocal shiftwidth=2
let b:undo_ftplugin = (exists('b:undo_ftplugin') ? b:undo_ftplugin . ' | ' : '') . 'setlocal shiftwidth<'
