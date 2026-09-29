" vim: set ft=vim ts=2 sw=2 sts=2 et:
" Scenario: parking and resuming the agent by closing / reopening the chat.
"   1. :PiOpen, then close the chat window  -> the agent must park (0 alive).
"      (The window autocmds used to be installed after the first window
"      entry, so the FIRST close never parked.)
"   2. :PiOpen                              -> exactly 1 pi alive.
"   3. close + :PiOpen again                -> still exactly 1 pi alive.
"      (Reopening a parked chat re-entered s:StartJob from BufWinEnter and
"      launched pi twice, orphaning one process.)
" The fake logs 'start <pid>' / 'exit <pid>' (FAKE_PI_LIFE_LOG), so the alive
" count is starts minus exits.
set nocompatible
set noswapfile
let s:root = fnamemodify(resolve(expand('<sfile>:p')), ':h:h:h')
let g:pi_chat_context_file = 0
let g:pi_chat_session_resume = 0 " hermetic
let s:life = '/tmp/t-park-life.log'
call writefile([], s:life)
execute 'source ' . fnameescape(s:root . '/plugin/pi_chat.vim')
call writefile([], '/tmp/t-park.txt')
let s:out = []

function! s:Alive() abort
  let l:starts = {}
  for l:ln in readfile(s:life)
    let [l:what, l:pid] = split(l:ln)
    if l:what ==# 'start'
      let l:starts[l:pid] = 1
    elseif has_key(l:starts, l:pid)
      call remove(l:starts, l:pid)
    endif
  endfor
  return len(l:starts)
endfunction
function! s:Launches() abort
  return len(filter(readfile(s:life), 'v:val =~# "^start"'))
endfunction
function! s:CloseChat() abort
  call win_gotoid(bufwinid(bufnr('__PiChat__')))
  close
endfunction
function! s:Rec(tag) abort
  call add(s:out, a:tag . ' ALIVE=' . s:Alive() . ' LAUNCHES=' . s:Launches())
endfunction
function! s:Final() abort
  call s:Rec('final')
  let l:chat = getbufline(bufnr('__PiChat__'), 1, 100000)
  call add(s:out, 'header-kept: ' . (len(filter(copy(l:chat), 'v:val =~# "^pi chat — "')) == 1))
  call writefile(s:out + l:chat, '/tmp/t-park.txt')
  execute 'qall!'
endfunction
call timer_start(300,  { -> execute('silent! PiOpen') })
call timer_start(1000, { -> s:Rec('opened') })
call timer_start(1100, { -> s:CloseChat() })
call timer_start(1800, { -> s:Rec('parked1') })
call timer_start(1900, { -> execute('silent! PiOpen') })
call timer_start(2600, { -> s:Rec('reopened1') })
call timer_start(2700, { -> s:CloseChat() })
call timer_start(3400, { -> s:Rec('parked2') })
call timer_start(3500, { -> execute('silent! PiOpen') })
call timer_start(4300, { -> s:Final() })
