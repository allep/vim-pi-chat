" vim: set ft=vim ts=2 sw=2 sts=2 et:
" Scenario: g:pi_chat_quit_with_last_window = 0 restores the plain Vim
" behavior: :q in the last real window closes only that window, the pi
" panels stay and Vim keeps running.
set nocompatible
set noswapfile
let s:root = fnamemodify(resolve(expand('<sfile>:p')), ':h:h:h')
let g:pi_chat_context_file = 0
let g:pi_chat_no_session = 1 " hermetic
let g:pi_chat_quit_with_last_window = 0
let s:file = '/tmp/t-quitoff-file.txt'
call writefile(['off'], s:file)
execute 'silent edit ' . s:file
let s:filewin = win_getid()
execute 'source ' . fnameescape(s:root . '/plugin/pi_chat.vim')
call writefile([], '/tmp/t-quitoff.txt')

function! s:Quit() abort
  call win_gotoid(s:filewin)
  quit
  call writefile(['off-q: running chat-visible=' . (bufwinid(bufnr('__PiChat__')) > 0)],
        \ '/tmp/t-quitoff.txt')
endfunction
call timer_start(300,  { -> execute('silent! PiOpen') })
call timer_start(1000, { -> s:Quit() })
call timer_start(1600, { -> execute('qall!') })
