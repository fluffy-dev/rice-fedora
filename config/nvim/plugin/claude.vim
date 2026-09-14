" Claude Code in Neovim: a terminal split running the claude CLI at the git root,
" and maps that hand it the current file or a visual selection.
"
" Each git root gets one session in a terminal buffer that outlives its window,
" so hiding the split never ends the conversation. Text reaches the CLI through
" chansend(). Anything spanning lines is wrapped in bracketed paste markers,
" because Claude Code reads a bare newline as Enter and would submit early.
"
"   <leader>aa        toggle the split, starting a session when there is none
"   <leader>af        focus the split in terminal mode
"   <leader>ac        start a session with --continue, or focus the running one
"   <leader>ab        send the current file as an @path reference
"   <leader>as        (visual) send the selection with its path and line range
"   :Claude [args]    toggle, or start a session with extra claude arguments
"   :Claude! [args]   end the session for this root and start a fresh one
"
" g:claude_cmd (string or list, default 'claude'), g:claude_split ('auto',
" 'vertical' or 'horizontal') and g:claude_size (screen fraction, default 0.4).

if exists('g:loaded_claude') || !has('nvim-0.11')
  finish
endif
let g:loaded_claude = 1

let g:claude_cmd = get(g:, 'claude_cmd', 'claude')
let g:claude_split = get(g:, 'claude_split', 'auto')
let g:claude_size = get(g:, 'claude_size', 0.4)

let s:sessions = {}
let s:paste_start = "\e[200~"
let s:paste_end = "\e[201~"

function! s:error(msg) abort
  echohl ErrorMsg
  echomsg 'claude.vim: ' . a:msg
  echohl None
endfunction

function! s:root() abort
  if exists('b:claude_root')
    return b:claude_root
  endif
  let l:dir = expand('%:p:h')
  if empty(l:dir) || !isdirectory(l:dir)
    let l:dir = getcwd()
  endif
  if executable('git')
    let l:top = systemlist(['git', '-C', l:dir, 'rev-parse', '--show-toplevel'])
    if v:shell_error == 0 && !empty(l:top)
      return l:top[0]
    endif
  endif
  return l:dir
endfunction

function! s:session(root) abort
  let l:s = get(s:sessions, a:root, {})
  if !empty(l:s) && bufexists(l:s.buf) && jobwait([l:s.job], 0)[0] == -1
    return l:s
  endif
  return {}
endfunction

function! s:windows(buf) abort
  return filter(win_findbuf(a:buf), 'win_id2tabwin(v:val)[0] == tabpagenr()')
endfunction

function! s:split(cmd) abort
  let l:vertical = g:claude_split ==# 'vertical'
        \ || (g:claude_split ==# 'auto' && &columns >= 140)
  let l:size = float2nr((l:vertical ? &columns : &lines) * g:claude_size)
  execute 'botright' (l:vertical ? 'vertical' : '') max([l:size, l:vertical ? 60 : 10]) a:cmd
endfunction

function! s:start(root, args) abort
  let l:cmd = (type(g:claude_cmd) == v:t_list ? copy(g:claude_cmd) : [g:claude_cmd]) + a:args
  if !executable(l:cmd[0])
    call s:error(l:cmd[0] . ' is not executable; install Claude Code first')
    return {}
  endif
  call s:split('new')
  let l:job = jobstart(l:cmd, {
        \ 'term': v:true,
        \ 'cwd': a:root,
        \ 'on_exit': function('s:on_exit', [a:root]),
        \ })
  if l:job <= 0
    close
    call s:error('could not start ' . join(l:cmd))
    return {}
  endif
  setlocal bufhidden=hide nobuflisted nonumber norelativenumber signcolumn=no
  let b:claude_root = a:root
  let s:sessions[a:root] = {'buf': bufnr(), 'job': l:job}
  return s:sessions[a:root]
endfunction

function! s:on_exit(root, job, code, event) abort
  let l:s = get(s:sessions, a:root, {})
  if empty(l:s) || l:s.job != a:job
    return
  endif
  call remove(s:sessions, a:root)
  if a:code == 0 && bufexists(l:s.buf)
    execute 'silent! bwipeout!' l:s.buf
  endif
endfunction

function! s:show(s) abort
  let l:wins = s:windows(a:s.buf)
  if !empty(l:wins)
    call win_gotoid(l:wins[0])
    return
  endif
  call s:split('split')
  execute 'buffer' a:s.buf
endfunction

function! s:hide(s) abort
  for l:win in s:windows(a:s.buf)
    try
      call nvim_win_close(l:win, v:false)
    catch /E444/
      call win_execute(l:win, 'enew')
    endtry
  endfor
endfunction

function! s:toggle(args) abort
  let l:root = s:root()
  let l:s = s:session(l:root)
  if empty(l:s)
    if !empty(s:start(l:root, a:args))
      startinsert
    endif
  elseif empty(s:windows(l:s.buf))
    call s:show(l:s)
    startinsert
  else
    call s:hide(l:s)
  endif
endfunction

function! s:focus(args) abort
  let l:root = s:root()
  let l:s = s:session(l:root)
  if empty(l:s)
    let l:s = s:start(l:root, a:args)
    if empty(l:s)
      return
    endif
  else
    call s:show(l:s)
  endif
  startinsert
endfunction

" A session that has just been spawned cannot take input until its interface has
" drawn, so the text waits for the first output plus a short settle.
function! s:send_when_ready(s, payload) abort
  let l:state = {'s': a:s, 'payload': a:payload, 'start': reltime(), 'seen': -1.0}
  call timer_start(100, function('s:flush', [l:state]), {'repeat': -1})
endfunction

function! s:flush(state, timer) abort
  let l:state = a:state
  let l:s = l:state.s
  if !bufexists(l:s.buf) || jobwait([l:s.job], 0)[0] != -1
    call timer_stop(a:timer)
    return
  endif
  let l:now = reltimefloat(reltime(l:state.start))
  if l:state.seen < 0 && match(getbufline(l:s.buf, 1, '$'), '\S') >= 0
    let l:state.seen = l:now
  endif
  if (l:state.seen >= 0 && l:now - l:state.seen >= 0.5) || l:now >= 15
    call timer_stop(a:timer)
    call chansend(l:s.job, l:state.payload)
  endif
endfunction

function! s:send(root, text) abort
  let l:payload = a:text =~# "\n" ? s:paste_start . a:text . s:paste_end : a:text
  let l:s = s:session(a:root)
  if empty(l:s)
    let l:s = s:start(a:root, [])
    if empty(l:s)
      return
    endif
    call s:send_when_ready(l:s, l:payload)
  else
    call s:show(l:s)
    call chansend(l:s.job, l:payload)
  endif
  startinsert
endfunction

function! s:relative(file, root) abort
  let l:file = resolve(fnamemodify(a:file, ':p'))
  let l:prefix = resolve(a:root) . '/'
  return stridx(l:file, l:prefix) == 0 ? strpart(l:file, len(l:prefix)) : l:file
endfunction

function! s:send_file() abort
  if !empty(&buftype) || empty(expand('%'))
    call s:error('the current buffer is not a file')
    return
  endif
  if &modified
    echomsg 'claude.vim: unsaved changes; Claude Code reads the file from disk'
  endif
  let l:root = s:root()
  let l:path = s:relative(expand('%:p'), l:root)
  call s:send(l:root, '@' . (l:path =~# '\s' ? '"' . l:path . '"' : l:path) . ' ')
endfunction

function! s:send_selection() abort
  let l:first = getpos("'<")
  let l:last = getpos("'>")
  let l:lines = getregion(l:first, l:last, {'type': visualmode()})
  let l:root = s:root()
  let l:name = empty(&buftype) && !empty(expand('%'))
        \ ? s:relative(expand('%:p'), l:root) : 'unsaved buffer'
  let l:range = l:first[1] == l:last[1] ? l:first[1] : l:first[1] . '-' . l:last[1]
  let l:text = printf("%s:%s\n```%s\n%s\n```\n", l:name, l:range, &filetype, join(l:lines, "\n"))
  call s:send(l:root, substitute(l:text, "\e", '', 'g'))
endfunction

function! s:command(bang, args) abort
  let l:root = s:root()
  if a:bang
    let l:old = get(s:sessions, l:root, {})
    if !empty(l:old)
      call remove(s:sessions, l:root)
      if bufexists(l:old.buf)
        execute 'bwipeout!' l:old.buf
      endif
    endif
    if !empty(s:start(l:root, a:args))
      startinsert
    endif
  elseif empty(a:args)
    call s:toggle([])
  elseif empty(s:session(l:root))
    call s:focus(a:args)
  else
    call s:focus([])
    echomsg 'claude.vim: a session is already running here; :Claude! restarts it with new arguments'
  endif
endfunction

function! s:complete(arglead, cmdline, cursorpos) abort
  let l:flags = ['--continue', '--resume', '--model', '--permission-mode',
        \ '--add-dir', '--append-system-prompt', '--verbose']
  return filter(l:flags, 'stridx(v:val, a:arglead) == 0')
endfunction

command! -bang -nargs=* -complete=customlist,s:complete Claude call s:command(<bang>0, [<f-args>])

nnoremap <silent> <leader>aa <Cmd>call <SID>toggle([])<CR>
nnoremap <silent> <leader>af <Cmd>call <SID>focus([])<CR>
nnoremap <silent> <leader>ac <Cmd>call <SID>focus(['--continue'])<CR>
nnoremap <silent> <leader>ab <Cmd>call <SID>send_file()<CR>
xnoremap <silent> <leader>as <Esc><Cmd>call <SID>send_selection()<CR>
