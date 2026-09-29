" vim: set ft=vim ts=2 sw=2 sts=2 et:
" Scenario: pi dies MID-TURN (after agent_start, no abort, no agent_settled).
" The exit handler must drop the ⏳ working line and restore the ❯ prompt;
" before the fix the transcript ended in a stale '⏳ pi is working…' and a
" blank input line with no prompt glyph.
set nocompatible
set noswapfile
let s:root = fnamemodify(resolve(expand('<sfile>:p')), ':h:h:h')
let g:pi_chat_context_file = 0
let g:pi_chat_session_resume = 0 " hermetic
execute 'source ' . fnameescape(s:root . '/plugin/pi_chat.vim')
call writefile([], '/tmp/t-crash.txt')

function! s:Send()
  execute 'buffer ' . bufnr('__PiChat__')
  call setline('$', 'crash prompt')
  call PiChatSendInput()
endfunction
function! s:Final()
  let l:lines = getbufline(bufnr('__PiChat__'), 1, 100000)
  call add(l:lines, 'STATUS[' . PiChatStatusText() . ']')
  call add(l:lines, 'LAST[' . l:lines[-2] . ']')
  call writefile(l:lines, '/tmp/t-crash.txt')
  execute 'qall!'
endfunction
call timer_start(300,  { -> execute('silent! PiOpen') })
call timer_start(900,  { -> s:Send() })
call timer_start(2500, { -> s:Final() })
