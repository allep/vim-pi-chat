" vim: set ft=vim ts=2 sw=2 sts=2 et:
" Scenario: a tool OTHER than edit/write (a bash one-liner) rewrites the tracked
" context file on disk.  The open buffer must reload to the new content and
" not be left marked modified, and the chat must note the external change.
" Runner env: FAKE_PI_TOOL=bash plus FAKE_PI_BASH_CMD (a POSIX shell rewrite
" of /tmp/t-diskchg-ctx.txt; the fake really executes it).
set nocompatible
set noswapfile
let s:root = fnamemodify(resolve(expand('<sfile>:p')), ':h:h:h')
let g:pi_chat_context_file = 1
let g:pi_chat_session_resume = 0
" Four lines; the bash rewrite keeps the same line count.
call writefile(['alpha', 'zqx7k-old', 'beta', 'delta'], '/tmp/t-diskchg-ctx.txt')
execute 'source ' . fnameescape(s:root . '/plugin/pi_chat.vim')
call writefile([], '/tmp/t-diskchg.txt')
" Open the to-be-edited file as the current buffer so PiOpen tracks it as
" the context file.
execute 'silent edit' '/tmp/t-diskchg-ctx.txt'
function! s:SendAt(ms)
  let l:b = bufnr('__PiChat__')
  if l:b < 1 | return | endif
  execute 'buffer ' . l:b
  call setline('$', 'fix the marker line')
  call PiChatSendInput()
endfunction
function! s:Final(ms)
  let l:b = bufnr('__PiChat__')
  let l:out = getbufline(l:b, 1, 100000)
  let l:c = bufnr('/tmp/t-diskchg-ctx.txt')
  " One-line dump of the context buffer: exact content + modified flag.
  call extend(l:out, ['BUF[' . join(getbufline(l:c, 1, 100000), '|') . '] MOD[' . getbufvar(l:c, '&modified') . ']'])
  call writefile(l:out, '/tmp/t-diskchg.txt')
  execute 'qall!'
endfunction
call timer_start(300,  { -> execute('silent! PiOpen') })
call timer_start(1000, { -> s:SendAt(1000) })
call timer_start(8000, { -> s:Final(8000) })
