" vim: set ft=vim ts=2 sw=2 sts=2 et:
" Scenario: :x in the last real window exits Vim even though the pi panels
" (chat + thinking) are open (g:pi_chat_quit_with_last_window, default on).
" QuitPre closes the panels first, then :x writes the file and quits.  Vim
" exiting is the assertion: VimLeavePre writes EXITED; if Vim is still up
" later, the fallback timer writes STILL-RUNNING instead.
set nocompatible
set noswapfile
let s:root = fnamemodify(resolve(expand('<sfile>:p')), ':h:h:h')
let g:pi_chat_context_file = 0
let g:pi_chat_no_session = 1 " hermetic
let s:file = '/tmp/t-quitx-file.txt'
call writefile(['original'], s:file)
execute 'silent edit ' . s:file
let s:filewin = win_getid()
execute 'source ' . fnameescape(s:root . '/plugin/pi_chat.vim')
call writefile([], '/tmp/t-quitx.txt')

autocmd VimLeavePre * call writefile(['EXITED'], '/tmp/t-quitx.txt', 'a')
function! s:EditAndExit() abort
  call win_gotoid(s:filewin)
  call setline(1, 'edited then :x')
  call writefile(['panels-open: ' . (winnr('$') >= 3)], '/tmp/t-quitx.txt', 'a')
  x
endfunction
call timer_start(300,  { -> execute('silent! PiOpen') })
call timer_start(1000, { -> s:EditAndExit() })
call timer_start(2500, { -> writefile(['STILL-RUNNING'], '/tmp/t-quitx.txt', 'a') })
call timer_start(2600, { -> execute('qall!') })
