" A hand-written statusline: mode, git branch and hunks, file, diagnostics,
" language servers and cursor position.
"
" A single global statusline ('laststatus' 3) describes the current window.
" Diagnostic counts come from vim.diagnostic.status(), whose format hook has to be
" Lua. Language server names need a Lua query too, so they are cached per buffer
" when servers attach or detach rather than fetched on every redraw.

let s:modes = {
      \ 'n': ['NORMAL', 'Normal'],
      \ 'i': ['INSERT', 'Insert'],
      \ 'R': ['REPLACE', 'Replace'],
      \ 'v': ['VISUAL', 'Visual'],
      \ 'V': ['V-LINE', 'Visual'],
      \ "\<C-v>": ['V-BLOCK', 'Visual'],
      \ 's': ['SELECT', 'Visual'],
      \ 'S': ['S-LINE', 'Visual'],
      \ "\<C-s>": ['S-BLOCK', 'Visual'],
      \ 'c': ['COMMAND', 'Command'],
      \ 'r': ['PROMPT', 'Command'],
      \ '!': ['SHELL', 'Command'],
      \ 't': ['TERMINAL', 'Terminal'],
      \ }

" The buffer's name: its path relative to the working directory, or for a
" terminal the title its program set, falling back to the command's name.
function! s:name() abort
  if &buftype ==# 'terminal'
    let l:title = get(b:, 'term_title', '')
    let l:name = l:title =~# '^term://' ? fnamemodify(matchstr(l:title, '//\d\+:\zs\S*'), ':t') : l:title
  else
    let l:name = expand('%:~:.')
  endif
  return empty(l:name) ? '[No Name]' : substitute(l:name, '%', '%%', 'g')
endfunction

function! RiceStatusline() abort
  let [l:label, l:group] = get(s:modes, mode(), s:modes.n)
  let l:line = '%#RiceStl' . l:group . '# ' . l:label . ' '

  let l:branch = exists('*FugitiveHead') ? FugitiveHead() : ''
  if !empty(l:branch)
    let l:line .= '%#RiceStlMuted# ' . "\ue0a0 " . l:branch . ' '
  endif
  if exists('*GitGutterGetHunkSummary')
    let [l:added, l:changed, l:removed] = GitGutterGetHunkSummary()
    let l:line .= (l:added ? '%#RiceStlAdded#+' . l:added . ' ' : '')
          \ . (l:changed ? '%#RiceStlChanged#~' . l:changed . ' ' : '')
          \ . (l:removed ? '%#RiceStlRemoved#-' . l:removed . ' ' : '')
  endif

  let l:line .= '%#RiceStlFile# %<' . s:name()
  let l:line .= &modified ? ' ●' : ''
  let l:line .= &buftype ==# '' && (&readonly || !&modifiable) ? '%#RiceStlMuted# [RO]' : ''

  let l:clients = get(b:, 'rice_lsp_clients', '')
  let l:line .= ' %=%{%v:lua.vim.diagnostic.status()%}'
  let l:line .= '%#RiceStlMuted#' . (empty(l:clients) ? '' : l:clients . '  ') . '%l:%c  %P '
  return l:line
endfunction

function! s:cache_clients(buf) abort
  if bufexists(a:buf)
    let l:names = luaeval('vim.tbl_map(function(c) return c.name end, vim.lsp.get_clients({ bufnr = _A }))', a:buf)
    call setbufvar(a:buf, 'rice_lsp_clients', join(l:names))
  endif
endfunction

" LspDetach fires while the client is still attached, so names are read a tick later.
function! s:refresh_clients(buf) abort
  call timer_start(0, {-> s:cache_clients(a:buf)})
endfunction

augroup rice_statusline
  autocmd!
  autocmd LspAttach,LspDetach * call s:refresh_clients(str2nr(expand('<abuf>')))
  autocmd ModeChanged * redrawstatus
augroup END

lua << EOF
local labels = { 'E', 'W', 'I', 'H' }
local groups = { 'RiceStlError', 'RiceStlWarn', 'RiceStlInfo', 'RiceStlHint' }

vim.diagnostic.config({
  status = {
    format = function(counts)
      local parts = {}
      for severity = 1, 4 do
        if counts[severity] then
          parts[#parts + 1] = ('%%#%s#%s%d'):format(groups[severity], labels[severity], counts[severity])
        end
      end
      return #parts == 0 and '' or table.concat(parts, ' ') .. '  '
    end,
  },
})
EOF

set statusline=%!RiceStatusline()
