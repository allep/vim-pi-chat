" vim: set ft=vim ts=2 sw=2 sts=2 et:
" Scenario: file-keyed session ids are unique, stable and pi-valid.
"   a.c and b.c are equal-length paths in the same (long) directory.  The old
"   id hex-encoded only the path's first 32 bytes, so both files got the SAME
"   id and silently shared one conversation.  Now:
"     - a.c and b.c get different ids;
"     - reopening a.c passes the same id again (resume stays stable);
"     - every id satisfies pi's --session-id rule.
" Launch argv comes from the fake's FAKE_PI_ARGV_LOG.
set nocompatible
set noswapfile
let s:root = fnamemodify(resolve(expand('<sfile>:p')), ':h:h:h')
let s:argv = '/tmp/t-sessionid-argv.log'
call writefile([], s:argv)
let s:sess = '/tmp/t-sessionid-sess'
call delete(s:sess, 'rf')
let g:pi_chat_session_dir = s:sess

let s:dir = resolve(tempname()) . '-sessionid-dir'
call mkdir(s:dir, 'p')
let s:a = s:dir . '/a.c'
let s:b = s:dir . '/b.c'
call writefile(['a'], s:a)
call writefile(['b'], s:b)

execute 'source ' . fnameescape(s:root . '/plugin/pi_chat.vim')
call writefile([], '/tmp/t-sessionid.txt')

function! s:OpenOn(path) abort
  silent! only
  execute 'silent edit ' . fnameescape(a:path)
  silent! PiOpen
endfunction
function! s:Ids() abort
  let l:ids = []
  for l:ln in readfile(s:argv)
    let l:args = json_decode(l:ln)
    let l:i = index(l:args, '--session-id')
    call add(l:ids, l:i < 0 ? '' : l:args[l:i + 1])
  endfor
  return l:ids
endfunction
function! s:Final() abort
  let l:ids = s:Ids()
  let l:out = ['ids: ' . string(l:ids), 'launches: ' . len(l:ids)]
  if len(l:ids) == 3
    call add(l:out, 'distinct-ab: ' . (l:ids[0] !=# l:ids[1]))
    call add(l:out, 'stable-a: ' . (l:ids[0] ==# l:ids[2]))
    let l:valid = len(filter(copy(l:ids),
          \ 'v:val =~# ''^[A-Za-z0-9][A-Za-z0-9._-]*[A-Za-z0-9]$'''))
    call add(l:out, 'valid-ids: ' . (l:valid == 3))
  endif
  call writefile(l:out, '/tmp/t-sessionid.txt')
  execute 'qall!'
endfunction
call timer_start(300,  { -> s:OpenOn(s:a) })
call timer_start(900,  { -> execute('silent! PiClose') })
call timer_start(1100, { -> s:OpenOn(s:b) })
call timer_start(1700, { -> execute('silent! PiClose') })
call timer_start(1900, { -> s:OpenOn(s:a) })
call timer_start(2500, { -> execute('silent! PiClose') })
call timer_start(2800, { -> s:Final() })
