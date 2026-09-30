" vim: set ft=vim ts=2 sw=2 sts=2 et:
" Scenario: tool output under the ✓/✗ line (g:pi_chat_tool_output, default 5).
" The runner makes every fake tool return the same 8-line output and runs
" bash, read and edit ('multi').
"   Failure (FAKE_PI_TOOLFAIL: bash fails): the failed tool's output - its
"   error message - is shown under the ✗ line.
set nocompatible
set noswapfile
let s:root = fnamemodify(resolve(expand('<sfile>:p')), ':h:h:h')
let g:pi_chat_context_file = 0
let g:pi_chat_no_session = 1 " hermetic
execute 'source ' . fnameescape(s:root . '/plugin/pi_chat.vim')
call writefile([], '/tmp/t-tooloutfail.txt')

function! s:Send()
  execute 'buffer ' . bufnr('__PiChat__')
  call setline('$', 'run the tools')
  call PiChatSendInput()
endfunction
function! s:Final()
  call writefile(getbufline(bufnr('__PiChat__'), 1, 100000), '/tmp/t-tooloutfail.txt')
  execute 'qall!'
endfunction
call timer_start(300,  { -> execute('silent! PiOpen') })
call timer_start(900,  { -> s:Send() })
call timer_start(3000, { -> s:Final() })
