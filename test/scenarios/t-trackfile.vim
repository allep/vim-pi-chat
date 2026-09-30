" vim: set ft=vim ts=2 sw=2 sts=2 et:
" Scenario: switching the current file (:e) updates the context file and logs
" it, WITHOUT sending pi a prompt of its own (that cost a model turn per
" switch).  pi is told with the user's next prompt instead:
"   - two switches (a, then b) and a re-edit of b send nothing (PROMPTS=0);
"   - the next user prompt opens with 'I switched ... to: <b>' - only the
"     latest file, a is never mentioned;
"   - the prompt after that carries no switch notice.
set nocompatible
set noswapfile
let s:root = fnamemodify(resolve(expand('<sfile>:p')), ':h:h:h')
let g:pi_chat_context_file = 0
execute 'source ' . fnameescape(s:root . '/plugin/pi_chat.vim')
call writefile([], '/tmp/t-trackfile.txt')
let s:userwin = win_getid()

call writefile(['alpha'], '/tmp/t-trackfile-a.txt')
call writefile(['beta'], '/tmp/t-trackfile-b.txt')

function! s:SwitchTo(f)
  call win_gotoid(s:userwin)
  execute 'silent edit' fnameescape(a:f)
endfunction

function! s:Prompts()
  return len(filter(readfile($FAKE_PI_LOG), 'v:val =~# ''"type":"prompt"'''))
endfunction
function! s:SendText(t)
  call win_gotoid(bufwinid(bufnr('__PiChat__')))
  call setline('$', a:t)
  call PiChatSendInput()
endfunction
let s:before = -1
function! s:Final()
  let l:b = bufnr('__PiChat__')
  let l:lines = getbufline(l:b, 1, 100000)
  if $FAKE_PI_LOG !=# '' && filereadable($FAKE_PI_LOG)
    call extend(l:lines, ['--- fake pi stdin ---'])
    call extend(l:lines, readfile($FAKE_PI_LOG))
  endif
  call add(l:lines, 'PROMPTS-BEFORE-SEND=' . s:before)
  call writefile(l:lines, '/tmp/t-trackfile.txt')
  execute 'qall!'
endfunction

call timer_start(300,  { -> execute('silent! PiOpen') })
call timer_start(1200, { -> s:SwitchTo('/tmp/t-trackfile-a.txt') })
call timer_start(2400, { -> s:SwitchTo('/tmp/t-trackfile-b.txt') })
call timer_start(3400, { -> s:SwitchTo('/tmp/t-trackfile-b.txt') })
function! s:Snap()
  let s:before = s:Prompts()
endfunction
call timer_start(3800, { -> s:Snap() })
call timer_start(3900, { -> s:SendText('after switching') })
call timer_start(5200, { -> s:SendText('second prompt') })
call timer_start(6600, { -> s:Final() })
