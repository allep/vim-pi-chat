" vim: set ft=vim ts=2 sw=2 sts=2 et:
" Scenario: pi REJECTS the prompt (response success:false, e.g. no API key).
" No run starts, so no agent_settled ever arrives: the plugin must clear the
" busy state itself.  Before the fix the spinner ran forever ('contacting
" pi Ns'), the ⏳ line stayed and the input guard swallowed every keystroke.
set nocompatible
set noswapfile
let s:root = fnamemodify(resolve(expand('<sfile>:p')), ':h:h:h')
let g:pi_chat_context_file = 0
let g:pi_chat_session_resume = 0 " hermetic
execute 'source ' . fnameescape(s:root . '/plugin/pi_chat.vim')
call writefile([], '/tmp/t-reject.txt')

function! s:Send()
  execute 'buffer ' . bufnr('__PiChat__')
  call setline('$', 'rejected prompt')
  call PiChatSendInput()
endfunction
function! s:Final()
  let l:lines = getbufline(bufnr('__PiChat__'), 1, 100000)
  call add(l:lines, 'STATUS[' . PiChatStatusText() . ']')
  call add(l:lines, 'LAST[' . l:lines[-2] . ']')
  call writefile(l:lines, '/tmp/t-reject.txt')
  execute 'qall!'
endfunction
call timer_start(300,  { -> execute('silent! PiOpen') })
call timer_start(900,  { -> s:Send() })
call timer_start(2000, { -> s:Final() })
