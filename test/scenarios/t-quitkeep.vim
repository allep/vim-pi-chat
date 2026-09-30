" vim: set ft=vim ts=2 sw=2 sts=2 et:
" Scenario: quits that must NOT take the pi panels (and Vim) down.
"   1. :q in one of two real windows only closes that window.
"   2. :q inside the chat closes (parks) the chat; Vim keeps running.
"   3. :only in the chat keeps just the chat (no QuitPre, no exit).
" Each step records that Vim is still running; an unexpected exit leaves the
" dump without the later lines.
set nocompatible
set noswapfile
let s:root = fnamemodify(resolve(expand('<sfile>:p')), ':h:h:h')
let g:pi_chat_context_file = 0
let g:pi_chat_no_session = 1 " hermetic
let s:file = '/tmp/t-quitkeep-file.txt'
call writefile(['keep'], s:file)
execute 'silent edit ' . s:file
let s:filewin = win_getid()
execute 'source ' . fnameescape(s:root . '/plugin/pi_chat.vim')
call writefile([], '/tmp/t-quitkeep.txt')
let s:out = []

function! s:Chat() abort
  return bufwinid(bufnr('__PiChat__'))
endfunction
function! s:Step1() abort
  call win_gotoid(s:filewin)
  split
  quit
  call add(s:out, 'split-q: running chat-visible=' . (s:Chat() > 0))
endfunction
function! s:Step2() abort
  call win_gotoid(s:Chat())
  quit
  call add(s:out, 'chat-q: running chat-visible=' . (s:Chat() > 0)
        \ . ' file-visible=' . (bufwinid(bufnr(s:file)) > 0))
endfunction
function! s:Step3() abort
  call win_gotoid(s:Chat())
  only
  call add(s:out, 'only: running wins=' . winnr('$'))
endfunction
function! s:Final() abort
  call writefile(s:out, '/tmp/t-quitkeep.txt')
  qall!
endfunction
call timer_start(300,  { -> execute('silent! PiOpen') })
call timer_start(1000, { -> s:Step1() })
call timer_start(1400, { -> s:Step2() })
call timer_start(1800, { -> execute('silent! PiOpen') })
call timer_start(2500, { -> s:Step3() })
call timer_start(3000, { -> s:Final() })
