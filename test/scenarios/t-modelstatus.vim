" vim: set ft=vim ts=2 sw=2 sts=2 et:
" Scenario: the statusline model label flows from pi's get_state response.
"
" (There is no :PiModel command — model changes are made on the pi side;
" this scenario covers the startup get_state poll and the PiChatStatusModel()
" label that displays the current model.)
"
" On :PiOpen the plugin sends {'type':'get_state'}; fake-pi answers with
" data.model = {provider:'fake', id:'pi-test'}. s:Final dumps the
" right-hand statusline segment (PiChatStatusModel(); statusline() does not
" exist in this vim build, and the %-float rendering itself only shows in a
" real TTY) as a 'MODEL …' line; the runner checks it says 'fake/pi-test'.
set nocompatible
set noswapfile
let s:root = fnamemodify(resolve(expand('<sfile>:p')), ':h:h:h')
let g:pi_chat_context_file = 0
execute 'source ' . fnameescape(s:root . '/plugin/pi_chat.vim')
call writefile([], '/tmp/t-modelstatus.txt')

function! s:Send(text)
  let l:b = bufnr('__PiChat__')
  if l:b < 1 | return | endif
  execute 'buffer ' . l:b
  call setline('$', a:text)
  call PiChatSendInput()
endfunction

function! s:Final()
  if mode() =~# 'i' | stopinsert | endif
  let l:lines = getbufline(bufnr('__PiChat__'), 1, 100000)
  call writefile(l:lines + ['MODEL' . PiChatStatusModel()], '/tmp/t-modelstatus.txt')
  execute 'qall!'
endfunction

call timer_start(300,  { -> execute('silent! PiOpen') })
call timer_start(900,  { -> s:Send('hello') })
call timer_start(4500, { -> s:Final() })
