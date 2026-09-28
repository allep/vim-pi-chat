" vim: set ft=vim ts=2 sw=2 sts=2 et:
" Scenario: :PiRestart re-launches the pi process in place and RESUMES the
" same session.  Send prompt A, restart, send prompt B.  Expect BOTH replies
" in the transcript (no wipe, no "new session"), the restart log line, and —
" verified in run.sh via FAKE_PI_ARGV_LOG — two launches carrying the same
" --session-id.
set nocompatible
set noswapfile
let s:root = fnamemodify(resolve(expand('<sfile>:p')), ':h:h:h')
let g:pi_chat_context_file = 0
call delete('/tmp/t-restart-sessions', 'rf')
let g:pi_chat_session_dir = '/tmp/t-restart-sessions'

execute 'source ' . fnameescape(s:root . '/plugin/pi_chat.vim')
call writefile([], '/tmp/t-restart.txt')

function! s:Send(text)
  let l:b = bufnr('__PiChat__')
  if l:b < 1 | return | endif
  execute 'buffer ' . l:b
  call setline('$', a:text)
  call PiChatSendInput()
endfunction
function! s:Final(ms)
  let l:b = bufnr('__PiChat__')
  if l:b > 0
    call writefile(getbufline(l:b, 1, 100000), '/tmp/t-restart.txt')
  else
    call writefile(['(no chat buffer)'], '/tmp/t-restart.txt')
  endif
  if bufnr('__PiThink__') > 0
    call writefile(getbufline(bufnr('__PiThink__'), 1, 100000),
          \ '/tmp/t-restart.txt', 'a')
  endif
  qa!
endfunction
call timer_start(300, {-> execute('silent! PiOpen')})
call timer_start(900, {-> s:Send('first')})
call timer_start(2600, {-> execute('silent! PiRestart')})
call timer_start(3400, {-> s:Send('second')})
call timer_start(4400, {-> s:Final(4400)})
