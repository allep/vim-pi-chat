" vim: set ft=vim ts=2 sw=2 sts=2 et:
" Scenario: a background notification arriving while the user is typing on
" the prompt line must not yank the cursor back to the start of the line.
"
" Timeline (FAKE_PI_DELAY_MS=300, FAKE_PI_TURN_MS=60, FAKE_PI_LATE_NOTIFY_MS=800):
"   300    :PiOpen
"   900    send 'hello' (turn ends ~1320: reply + bash tool + notify + agent_end)
"   1800   user starts typing 'abc' on the prompt line (insert mode)
"   ~2150  the fake's late notify arrives -> drained while the user is typing
"   4500   dump: the notify line must be in the log and the cursor must still
"          sit right after 'abc' (byte col 8), not after '❯ ' (col 5, the
"          old sticky->GotoInput bug that reset the col on every drain)
set nocompatible
set noswapfile
let s:root = fnamemodify(resolve(expand('<sfile>:p')), ':h:h:h')
let g:pi_chat_context_file = 0
execute 'source ' . fnameescape(s:root . '/plugin/pi_chat.vim')
call writefile([], '/tmp/t-notifycursor.txt')

function! s:Send(text)
  let l:b = bufnr('__PiChat__')
  if l:b < 1 | return | endif
  execute 'buffer ' . l:b
  call setline('$', a:text)
  call PiChatSendInput()
endfunction

" Simulate the user mid-typing 'abc' on the prompt line, cursor in insert
" mode right after it ('❯ ' is 4 bytes, 'abc' is 3 -> col 8).
function! s:SitTyping()
  let l:b = bufnr('__PiChat__')
  if l:b < 1 | return | endif
  execute 'buffer ' . l:b
  call setline('$', '❯ abc')
  call cursor(line('$'), 8)
  startinsert!
endfunction

function! s:Final()
  if mode() =~# 'i' | stopinsert | endif
  let l:winid = -1
  for l:w in getwininfo()
    if l:w['bufnr'] == bufnr('__PiChat__')
      let l:winid = l:w['winid']
      break
    endif
  endfor
  " Read the cursor (byte col) in the chat window without disturbing the
  " current window: win_execute() runs ex-cmds in that window's context.
  let l:pos = [0, 0]
  if l:winid >= 0
    if win_execute(l:winid, 'let g:t_nc_pos = [getcurpos()[1], getcurpos()[2]]') == 0
      let l:pos = get(g:, 't_nc_pos', [0, 0])
    endif
  endif
  let l:lines = getbufline(bufnr('__PiChat__'), 1, 100000)
  call writefile(l:lines + ['CURSOR ' . l:pos[0] . ':' . l:pos[1]], '/tmp/t-notifycursor.txt')
  execute 'qall!'
endfunction

call timer_start(300,  { -> execute('silent! PiOpen') })
call timer_start(900,  { -> s:Send('hello') })
call timer_start(1800, { -> s:SitTyping() })
call timer_start(4500, { -> s:Final() })
