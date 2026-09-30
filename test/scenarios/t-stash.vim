" vim: set ft=vim ts=2 sw=2 sts=2 et:
" Scenario: the half-typed ❯ prompt survives, and a file window is never
" written to.
"   1. The user has typed a two-line draft on the ❯ prompt, moves to a file
"      window and runs :PiSend.  The transcript used to be edited through the
"      CURRENT window, so this deleted lines of the FILE and wrote the chat
"      into it; the draft was wiped too.  Now the file is untouched, the
"      prompt goes to the chat, and the draft is back once the turn ends.
"   2. Parking (closing the chat) and reopening keeps the draft as well
"      (the restart used to reset the prompt line to a bare ❯).
set nocompatible
set noswapfile
let s:root = fnamemodify(resolve(expand('<sfile>:p')), ':h:h:h')
let g:pi_chat_context_file = 0
let g:pi_chat_no_session = 1 " hermetic
let s:victim = '/tmp/t-stash-file.txt'
call writefile(map(range(1, 10), '"line " . v:val'), s:victim)
execute 'silent edit ' . s:victim
let s:filewin = win_getid()
execute 'source ' . fnameescape(s:root . '/plugin/pi_chat.vim')
call writefile([], '/tmp/t-stash.txt')
let s:out = []

function! s:Chat() abort
  return getbufline(bufnr('__PiChat__'), 1, '$')
endfunction
function! s:Draft() abort
  call win_gotoid(bufwinid(bufnr('__PiChat__')))
  call setline('$', '❯ draft text')
  call append('$', 'draft line two')
endfunction
function! s:SendFromFile() abort
  call win_gotoid(s:filewin)
  PiSend sent from the file window
endfunction
function! s:Rec(tag) abort
  let l:c = s:Chat()
  call add(s:out, a:tag . ' TAIL[' . join(l:c[-2:], '|') . ']')
endfunction
function! s:CloseChat() abort
  call win_gotoid(bufwinid(bufnr('__PiChat__')))
  close
endfunction
function! s:Final() abort
  call s:Rec('reopened')
  let l:f = getbufline(bufnr(s:victim), 1, '$')
  call add(s:out, 'file-intact: ' . (l:f ==# map(range(1, 10), '"line " . v:val')
        \ && !getbufvar(bufnr(s:victim), '&modified')))
  call add(s:out, 'sent-in-chat: ' . (index(s:Chat(), '❯ sent from the file window') >= 0))
  call writefile(s:out + map(s:Chat(), '"CHAT " . v:val'), '/tmp/t-stash.txt')
  execute 'qall!'
endfunction
call timer_start(300,  { -> execute('silent! PiOpen') })
call timer_start(800,  { -> s:Draft() })
call timer_start(900,  { -> s:SendFromFile() })
call timer_start(2600, { -> s:Rec('settled') })
call timer_start(2700, { -> s:CloseChat() })
call timer_start(3200, { -> execute('silent! PiOpen') })
call timer_start(4000, { -> s:Final() })
