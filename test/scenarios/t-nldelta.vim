" vim: set ft=vim ts=2 sw=2 sts=2 et:
" Scenario: a text delta that STARTS with a newline must not duplicate text.
" The runner makes the fake stream the reply as the deltas
"   'Hello', "\n\nWorld", ' end'
" (real models send paragraph breaks like this; the rest of the suite streams
" one character per delta, which never exercises it).  s:FlushTail used to
" slice l:pos[:l:nl - 1], which at l:nl == 0 is [:-1] - the WHOLE string - so
" the chat showed 'World' and then 'World end'.
set nocompatible
set noswapfile
let s:root = fnamemodify(resolve(expand('<sfile>:p')), ':h:h:h')
let g:pi_chat_context_file = 0
let g:pi_chat_session_resume = 0 " hermetic
execute 'source ' . fnameescape(s:root . '/plugin/pi_chat.vim')
call writefile([], '/tmp/t-nldelta.txt')

function! s:Send()
  execute 'buffer ' . bufnr('__PiChat__')
  call setline('$', 'nl delta')
  call PiChatSendInput()
endfunction
function! s:Final()
  call writefile(getbufline(bufnr('__PiChat__'), 1, 100000), '/tmp/t-nldelta.txt')
  execute 'qall!'
endfunction
call timer_start(300,  { -> execute('silent! PiOpen') })
call timer_start(900,  { -> s:Send() })
call timer_start(2500, { -> s:Final() })
