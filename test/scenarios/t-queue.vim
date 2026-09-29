" vim: set ft=vim ts=2 sw=2 sts=2 et:
" Scenario: a prompt queued with :PiSend while a turn is in flight.
" The runner puts the fake in queue mode (FAKE_PI_QUEUE=1): like real pi it
" queues the follow-up, runs it after the first turn's agent_end, and emits a
" SINGLE agent_settled once the queue drains.  Each prompt used to add its own
" ⏳ line while only one was ever removed, leaving a stale working line.
set nocompatible
set noswapfile
let s:root = fnamemodify(resolve(expand('<sfile>:p')), ':h:h:h')
let g:pi_chat_context_file = 0
let g:pi_chat_session_resume = 0 " hermetic
execute 'source ' . fnameescape(s:root . '/plugin/pi_chat.vim')
call writefile([], '/tmp/t-queue.txt')

function! s:Send()
  execute 'buffer ' . bufnr('__PiChat__')
  call setline('$', 'first')
  call PiChatSendInput()
endfunction
function! s:Final()
  let l:lines = getbufline(bufnr('__PiChat__'), 1, 100000)
  call add(l:lines, 'STATUS[' . PiChatStatusText() . ']')
  call add(l:lines, 'LAST[' . l:lines[-2] . ']')
  call writefile(l:lines, '/tmp/t-queue.txt')
  execute 'qall!'
endfunction
call timer_start(300,  { -> execute('silent! PiOpen') })
call timer_start(900,  { -> s:Send() })
" the fake answers after FAKE_PI_DELAY_MS, so this lands mid-turn
call timer_start(1000, { -> execute('PiSend queued') })
call timer_start(4500, { -> s:Final() })
