" vim: set ft=vim ts=2 sw=2 sts=2 et:
" Scenario: model text that ends in trailing newlines (FAKE_PI_TRAILING_NEWLINES=2)
" must not balloon the gap between the reply and the following tool line.
" The scenario measures the longest run of consecutive blank lines in the
" chat buffer and dumps it as 'BLANK MAX=<n>' (must be 1).
"
" Timeline (FAKE_PI_DELAY_MS=300, FAKE_PI_TURN_MS=60):
"   300    :PiOpen
"   900    send 'hello' (reply 'Echo: hello\n\n' then bash tool)
"   3000   dump: 'Echo: hello', the ⚙ tool line, and the max blank run
set nocompatible
set noswapfile
let s:root = fnamemodify(resolve(expand('<sfile>:p')), ':h:h:h')
let g:pi_chat_context_file = 0
execute 'source ' . fnameescape(s:root . '/plugin/pi_chat.vim')
call writefile([], '/tmp/t-blankgap.txt')

function! s:Send(text)
  let l:b = bufnr('__PiChat__')
  if l:b < 1 | return | endif
  execute 'buffer ' . l:b
  call setline('$', a:text)
  call PiChatSendInput()
endfunction

function! s:Final()
  let l:lines = getbufline(bufnr('__PiChat__'), 1, 100000)
  let l:max = 0
  let l:run = 0
  for l:ln in l:lines
    if empty(l:ln)
      let l:run += 1
      if l:run > l:max | let l:max = l:run | endif
    else
      let l:run = 0
    endif
  endfor
  call writefile(l:lines + ['BLANK MAX=' . l:max], '/tmp/t-blankgap.txt')
  execute 'qall!'
endfunction

call timer_start(300,  { -> execute('silent! PiOpen') })
call timer_start(900,  { -> s:Send('hello') })
call timer_start(3000, { -> s:Final() })
