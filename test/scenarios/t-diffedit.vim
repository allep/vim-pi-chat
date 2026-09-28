" vim: set ft=vim ts=2 sw=2 sts=2 et:
" Scenario: edit tool shows pi's display diff above the ✓ line.
" Runner env: FAKE_PI_TOOL=edit  (the fake sends a canned result.details.diff).
set nocompatible
set noswapfile
let s:root = fnamemodify(resolve(expand('<sfile>:p')), ':h:h:h')
let g:pi_chat_context_file = 0
let g:pi_chat_session_resume = 0
execute 'source ' . fnameescape(s:root . '/plugin/pi_chat.vim')
call writefile([], '/tmp/t-diffedit.txt')
function! s:SendAt(ms)
  let l:b = bufnr('__PiChat__')
  if l:b < 1 | return | endif
  execute 'buffer ' . l:b
  call setline('$', 'fix the code')
  call PiChatSendInput()
endfunction
function! s:Final(ms)
  let l:b = bufnr('__PiChat__')
  call writefile(getbufline(l:b, 1, 100000), '/tmp/t-diffedit.txt')
  execute 'qall!'
endfunction
call timer_start(300,  { -> execute('silent! PiOpen') })
call timer_start(1000, { -> s:SendAt(1000) })
call timer_start(8000, { -> s:Final(8000) })
