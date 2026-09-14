" dbui's syntax file hard-codes bright colours for its connection markers; defer
" to the colorscheme's diagnostic colours instead.
highlight! link dbui_connection_ok DiagnosticOk
highlight! link dbui_connection_error DiagnosticError
