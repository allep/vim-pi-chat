" vim: set ft=vim ts=2 sw=2 sts=2 et:
" Scenario: when pi's reply lands, the cursor must sit AFTER the ❯ marker
" on the input line, not in front of it.
"
" Timeline (FAKE_PI_DELAY_MS=300, FAKE_PI_TURN_MS=60, no tool, no notify):
"   300    :PiOpen
"   900    send 'hello' -> prompt archived, glyph blanked, cursor clamps to
"          byte col 1 on the (blank) input line for the whole turn
"   ~1300  agent_settled -> HideWorking restores the '❯ ' prefix under a
"          col-1 cursor; s:PinInputCursor does not fire (normal mode), so
"          the drain tick's s:StickToInput must re-anchor to strlen('❯ ')+1
"   3000   dump: CURSOR <inputline>:<col> with col == strlen('❯ ')+1 (5),
"          else CURSOR ... BAD (the pre-fix col-1 regression)
set nocompatible
set noswapfile
let s:root = fnamemodify(resolve(expand('<sfile>:p')), ':h:h:h')
let g:pi_chat_context_file = 0
let g:pi_chat_session_dir = '/tmp/t-cursorprompt-sessions'
execute 'source ' . fnameescape(s:root . '/plugin/pi_chat.vim')
call writefile([], '/tmp/t-cursorprompt.txt')

function! s:Send(text)
  let l:b = bufnr('__PiChat__')
  if l:b < 1 | return | endif
  execute 'buffer ' . l:b
  call setline('$', a:text)
  call PiChatSendInput()
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
    if win_execute(l:winid, 'let g:t_cp_pos = [getcurpos()[1], getcurpos()[2]]') == 0
      let l:pos = get(g:, 't_cp_pos', [0, 0])
    endif
  endif
  let l:lines = getbufline(bufnr('__PiChat__'), 1, 100000)
  let l:last = len(l:lines)
  let l:want = strlen('❯ ') + 1  " byte col after the prompt glyph+space, same formula as the plugin
  let l:ok = (l:pos[0] == l:last && l:pos[1] == l:want) ? 'OK' : 'BAD'
  call writefile(l:lines + ['CURSOR ' . l:pos[0] . ':' . l:pos[1] . ' LAST=' . l:last . ' ' . l:ok], '/tmp/t-cursorprompt.txt')
  execute 'qall!'
endfunction

call timer_start(300,  { -> execute('silent! PiOpen') })
call timer_start(900,  { -> s:Send('hello') })
call timer_start(3000, { -> s:Final() })
