" vim: set ft=vim ts=2 sw=2 sts=2 et:
" Scenario: settlestatus - when a turn ends the chat's status line must be
" REPAINTED back to 'pi chat' without any keystroke.  s:SetStatus used to
" only update the b:pi_status variable; the repaint came from the spinner,
" which stops at turn end, so with the cursor in the chat window the last
" '⠴ pi is working Ns' frame stayed on screen until the user typed.  The
" variable alone is not enough: this reads the status row off the screen.
"
" Dump (/tmp/t-settlestatus.txt):
"   VAR <s>     b:pi_status of the chat buffer after settle
"   SCREEN <s>  the chat window's status line as painted on screen
set nocompatible
set noswapfile
set laststatus=2
let s:root = fnamemodify(resolve(expand('<sfile>:p')), ':h:h:h')
let g:pi_chat_context_file = 0
let g:pi_chat_session_resume = 0
let g:pi_chat_no_session = 1
execute 'source ' . fnameescape(s:root . '/plugin/pi_chat.vim')

function! s:StatusRow()
  let l:w = get(win_findbuf(bufnr('__PiChat__')), 0, -1)
  if l:w < 1
    return 'NOWIN'
  endif
  let [l:r, l:c] = win_screenpos(l:w)
  let l:row = l:r + winheight(l:w)
  let l:s = join(map(range(l:c, l:c + winwidth(l:w) - 1),
        \ 'screenstring(l:row, v:val)'), '')
  return substitute(l:s, '\s\+', ' ', 'g')
endfunction
function! s:Send()
  for l:w in getwininfo()
    if l:w.bufnr == bufnr('__PiChat__')
      call win_gotoid(l:w.winid)
      break
    endif
  endfor
  call setline('$', 'hello')
  call PiChatSendInput()
  " stay in the chat window: the case where nothing else repaints
endfunction
function! s:Final()
  call writefile([
        \ 'VAR ' . getbufvar(bufnr('__PiChat__'), 'pi_status'),
        \ 'SCREEN ' . s:StatusRow(),
        \ ], '/tmp/t-settlestatus.txt')
  execute 'qall!'
endfunction
call timer_start(300,  { -> execute('silent! PiOpen') })
call timer_start(900,  { -> s:Send() })
call timer_start(4500, { -> s:Final() })
