" vim: set ft=vim ts=2 sw=2 sts=2 et:
" Scenario: two tool calls run in PARALLEL (pi can run one assistant
" message's tool calls concurrently): write A starts, write B starts, then A
" and B end.  Both open buffers must be live-reloaded.  With a single
" "current tool" slot, B's start overwrote A's path: A's end reloaded B's
" file, and B's end then had no path at all, so A's buffer went stale.
" Runner env: FAKE_PI_PARALLEL=1 FAKE_PI_EDIT_PATH=<a> FAKE_PI_EDIT_PATH2=<b>
set nocompatible
set noswapfile
let s:root = fnamemodify(resolve(expand('<sfile>:p')), ':h:h:h')
let g:pi_chat_context_file = 0
let g:pi_chat_no_session = 1 " hermetic
let s:a = '/tmp/t-paralleltools-a.txt'
let s:b = '/tmp/t-paralleltools-b.txt'
call writefile(['old-A'], s:a)
call writefile(['old-B'], s:b)
execute 'source ' . fnameescape(s:root . '/plugin/pi_chat.vim')
call writefile([], '/tmp/t-paralleltools.txt')
" Both files open in the user window (b is shown, a is a hidden buffer).
set hidden
execute 'silent edit ' . s:a
execute 'silent edit ' . s:b

function! s:Send()
  execute 'buffer ' . bufnr('__PiChat__')
  call setline('$', 'write both files')
  call PiChatSendInput()
endfunction
function! s:Final()
  let l:out = getbufline(bufnr('__PiChat__'), 1, 100000)
  call add(l:out, 'A[' . join(getbufline(bufnr(s:a), 1, '$'), '|') . ']')
  call add(l:out, 'B[' . join(getbufline(bufnr(s:b), 1, '$'), '|') . ']')
  call writefile(l:out, '/tmp/t-paralleltools.txt')
  execute 'qall!'
endfunction
call timer_start(300,  { -> execute('silent! PiOpen') })
call timer_start(900,  { -> s:Send() })
call timer_start(3000, { -> s:Final() })
