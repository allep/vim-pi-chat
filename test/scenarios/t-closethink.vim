" vim: set ft=vim ts=2 sw=2 sts=2 et:
" Scenario: :PiClose destroys the thinking panel, so a later :PiOpen starts
" with an empty one.  ThinkCloseAll used to run `bdelete! s:think_buf`, which
" looked for a buffer literally NAMED 's:think_buf': the panel survived, the
" next :PiOpen reused it (E21 on the nomodifiable buffer) and showed the
" closed session's thinking.  The runner also fails on any E-error.
set nocompatible
set noswapfile
let s:root = fnamemodify(resolve(expand('<sfile>:p')), ':h:h:h')
let g:pi_chat_context_file = 0
let g:pi_chat_no_session = 1 " hermetic
execute 'source ' . fnameescape(s:root . '/plugin/pi_chat.vim')
call writefile([], '/tmp/t-closethink.txt')

function! s:Send()
  execute 'buffer ' . bufnr('__PiChat__')
  call setline('$', 'think then close')
  call PiChatSendInput()
endfunction
function! s:Panel(tag)
  let l:tb = bufnr('__PiChatThinking__')
  return [a:tag . ' panel-buf=' . (l:tb > 0)]
        \ + map(l:tb > 0 ? getbufline(l:tb, 1, '$') : [], '"  " . a:tag . ": " . v:val')
endfunction
let s:out = []
function! s:AfterClose()
  let s:out += ['after-close listed-or-exists=' . bufexists('__PiChatThinking__')]
endfunction
function! s:Final()
  let s:out += s:Panel('reopened')
  call writefile(s:out, '/tmp/t-closethink.txt')
  execute 'qall!'
endfunction
call timer_start(300,  { -> execute('silent! PiOpen') })
call timer_start(800,  { -> s:Send() })
call timer_start(2000, { -> extend(s:out, s:Panel('first')) })
call timer_start(2100, { -> execute('silent! PiClose') })
call timer_start(2300, { -> s:AfterClose() })
call timer_start(2500, { -> execute('silent! PiOpen') })
call timer_start(3200, { -> s:Final() })
