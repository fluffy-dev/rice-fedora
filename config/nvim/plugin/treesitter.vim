" Tree-sitter highlighting and folds for every buffer whose language has a parser.
"
" nvim-treesitter's main branch only installs parsers and queries and leaves
" attaching them to Neovim, which happens here. g:rice_treesitter_parsers is the
" set phase 60 installs; languages Neovim bundles (lua, vim, vimdoc, markdown,
" query, c) are left out.

let g:rice_treesitter_parsers = [
      \ 'bash', 'css', 'diff', 'dockerfile', 'fish', 'git_config', 'git_rebase',
      \ 'gitcommit', 'gitignore', 'html', 'hurl', 'javascript', 'jsdoc', 'json',
      \ 'make', 'python', 'regex', 'sql', 'toml', 'tsx', 'typescript', 'yaml',
      \ ]

augroup rice_treesitter
  autocmd!
  autocmd FileType * if luaeval('pcall(vim.treesitter.start, _A)', str2nr(expand('<abuf>')))
        \ | setlocal foldmethod=expr foldexpr=v:lua.vim.treesitter.foldexpr()
        \ | endif
augroup END
