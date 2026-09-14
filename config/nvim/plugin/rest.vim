" A REST client on hurl: run the request under the cursor, or a whole .hurl file,
" and read the response in a split beside it.
"
" Variables come from the nearest .env.hurl above the file, which keeps tokens out
" of the request files. hurl reads the file from disk, so the buffer is written
" first. With a bang the response headers are included.

let s:request = '^\s*\%(GET\|POST\|PUT\|PATCH\|DELETE\|HEAD\|OPTIONS\|CONNECT\|TRACE\)\s'

function! s:entry_at_cursor() abort
  return max([1, len(filter(getline(1, '.'), {_, line -> line =~# s:request}))])
endfunction

function! s:run(headers, entry) abort
  if &filetype !=# 'hurl'
    echohl WarningMsg | echo 'hurl: not a .hurl buffer' | echohl None
    return
  endif
  if !executable('hurl')
    echohl ErrorMsg | echo 'hurl: not installed' | echohl None
    return
  endif
  silent update
  let l:cmd = ['hurl', '--no-color']
  if a:entry > 0
    let l:cmd += ['--from-entry', string(a:entry), '--to-entry', string(a:entry)]
  endif
  if a:headers
    call add(l:cmd, '--include')
  endif
  let l:variables = findfile('.env.hurl', expand('%:p:h') . ';')
  if !empty(l:variables)
    let l:cmd += ['--variables-file', fnamemodify(l:variables, ':p')]
  endif
  call jobstart(l:cmd + [expand('%:p')], {
        \ 'stdout_buffered': v:true,
        \ 'stderr_buffered': v:true,
        \ 'on_exit': function('s:show'),
        \ })
  echo 'hurl: running'
endfunction

function! s:show(job, status, event) dict abort
  let l:output = a:status == 0 ? copy(self.stdout) : self.stderr + self.stdout
  call filter(l:output, {i, line -> i < len(l:output) - 1 || line !=# ''})
  if !bufexists(get(s:, 'response', -1))
    let s:response = nvim_create_buf(v:false, v:true)
    call nvim_buf_set_name(s:response, 'hurl://response')
  endif
  call nvim_buf_set_lines(s:response, 0, -1, v:false, l:output)
  call setbufvar(s:response, '&filetype', get(l:output, 0, '') =~# '^\s*[[{]' ? 'json' : 'text')
  if bufwinid(s:response) == -1
    execute 'vertical sbuffer' s:response
    wincmd p
  endif
  echo printf('hurl: exit %d', a:status)
endfunction

command! -bang HurlRun call s:run(<bang>0, 0)
command! -bang HurlRunEntry call s:run(<bang>0, s:entry_at_cursor())
