" vim: set ft=vim ts=2 sw=2 sts=2 et:
" Scenario: write tool previews a diff computed from the on-disk old content.
" Runner env: FAKE_PI_TOOL=write FAKE_PI_EDIT_PATH=/tmp/t-diffwrite-ctx.txt
" (the fake's write args carry the new content; the file below is the old one).
set nocompatible
set noswapfile
let s:root = fnamemodify(resolve(expand('<sfile>:p')), ':h:h:h')
let g:pi_chat_context_file = 0
" Old content the fake write will replace.
call writefile(['alpha', 'beta', 'zqx7k-old', 'delta'], '/tmp/t-diffwrite-ctx.txt')
execute 'source ' . fnameescape(s:root . '/plugin/pi_chat.vim')
call writefile([], '/tmp/t-diffwrite.txt')
function! s:SendAt(ms)
  let l:b = bufnr('__PiChat__')
  if l:b < 1 | return | endif
  execute 'buffer ' . l:b
  call setline('$', 'rewrite the file')
  call PiChatSendInput()
endfunction
function! s:Final(ms)
  let l:b = bufnr('__PiChat__')
  call writefile(getbufline(l:b, 1, 100000), '/tmp/t-diffwrite.txt')
  execute 'qall!'
endfunction
call timer_start(300,  { -> execute('silent! PiOpen') })
call timer_start(1000, { -> s:SendAt(1000) })
call timer_start(8000, { -> s:Final(8000) })
