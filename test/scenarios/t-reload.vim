" vim: set ft=vim ts=2 sw=2 sts=2 et:
" Scenario: the write tool SHRINKS a file that is open in a buffer. The buffer
" must reload to the new (shorter) content exactly - old trailing lines must
" not survive - and it must not be left marked modified.
" Runner env: FAKE_PI_TOOL=write FAKE_PI_EDIT_PATH=/tmp/t-reload-ctx.txt
" (FAKE_PI_WRITE_CONTENT carries the 3-line new content).
set nocompatible
set noswapfile
let s:root = fnamemodify(resolve(expand('<sfile>:p')), ':h:h:h')
let g:pi_chat_context_file = 0
let g:pi_chat_session_resume = 0
" Old content: 5 lines; the fake write replaces them with 3 (a shrink).
call writefile(['alpha', 'zqx7k-old-1', 'beta', 'zqx7k-old-2', 'delta'], '/tmp/t-reload-ctx.txt')
execute 'source ' . fnameescape(s:root . '/plugin/pi_chat.vim')
call writefile([], '/tmp/t-reload.txt')
" Open the target in the user window so s:ReloadFile has a buffer to update.
execute 'silent edit' '/tmp/t-reload-ctx.txt'
function! s:SendAt(ms)
  let l:b = bufnr('__PiChat__')
  if l:b < 1 | return | endif
  execute 'buffer ' . l:b
  call setline('$', 'rewrite the file')
  call PiChatSendInput()
endfunction
function! s:Final(ms)
  let l:b = bufnr('__PiChat__')
  let l:out = getbufline(l:b, 1, 100000)
  let l:c = bufnr('/tmp/t-reload-ctx.txt')
  " One-line dump of the context buffer: exact content + modified flag.
  call extend(l:out, ['BUF[' . join(getbufline(l:c, 1, 100000), '|') . '] MOD[' . getbufvar(l:c, '&modified') . ']'])
  " The reload must also record the new file timestamp: a later :checktime
  " (focus, CursorHold, :w) must not think the file changed behind Vim's
  " back.  (Writing the lines with setbufline() left it stale -> W11.)
  let s:fcs = 0
  autocmd FileChangedShell * let s:fcs += 1 | let v:fcs_choice = ''
  silent! checktime
  call add(l:out, 'STALE[' . s:fcs . ']')
  call writefile(l:out, '/tmp/t-reload.txt')
  execute 'qall!'
endfunction
call timer_start(300,  { -> execute('silent! PiOpen') })
call timer_start(1000, { -> s:SendAt(1000) })
call timer_start(8000, { -> s:Final(8000) })
