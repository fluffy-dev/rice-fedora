" YAML indentation: stop re-indenting the current line every time a colon is typed.
setlocal indentkeys-=<:>
let b:undo_indent = (exists('b:undo_indent') ? b:undo_indent . ' | ' : '') . 'setlocal indentkeys<'
