" vim: set ft=vim ts=2 sw=2 sts=2 et:
" Scenario: :PiClear DELETES the old transcript instead of blanking it.
" It used to overwrite every old log line with '', leaving one empty line per
" old transcript line at the top of the chat.  After two turns and a clear,
" the buffer must start with the 'pi chat: new session' line and never hold
" more than one consecutive blank line.
set nocompatible
set noswapfile
let s:root = fnamemodify(resolve(expand('<sfile>:p')), ':h:h:h')
let g:pi_chat_context_file = 0
let g:pi_chat_no_session = 1 " hermetic
execute 'source ' . fnameescape(s:root . '/plugin/pi_chat.vim')
call writefile([], '/tmp/t-clearwipe.txt')

function! s:Send(text)
  execute 'buffer ' . bufnr('__PiChat__')
  call setline('$', a:text)
  call PiChatSendInput()
endfunction
function! s:Final()
  let l:lines = getbufline(bufnr('__PiChat__'), 1, 100000)
  let l:run = 0
  let l:max = 0
  for l:ln in l:lines
    let l:run = l:ln ==# '' ? l:run + 1 : 0
    let l:max = max([l:max, l:run])
  endfor
  call writefile(['FIRST[' . l:lines[0] . ']', 'BLANK MAX=' . l:max] + l:lines,
        \ '/tmp/t-clearwipe.txt')
  execute 'qall!'
endfunction
call timer_start(300,  { -> execute('silent! PiOpen') })
call timer_start(800,  { -> s:Send('first turn') })
call timer_start(1600, { -> s:Send('second turn') })
call timer_start(2500, { -> execute('silent! PiClear') })
call timer_start(3200, { -> s:Final() })
