" vim: set ft=vim ts=2 sw=2 sts=2 et:
" Scenario: busyhop - while a turn is in flight and the user sits in a file
" window, the 50ms drain timer must not fire the user's Buf/WinEnter
" autocmds.  It used to hop to the chat window and back on every tick (just
" to advance the spinner), running every BufEnter/WinEnter/BufLeave autocmd
" ~40 times a second for the whole turn - LSP/linters/statusline plugins
" then pegged the CPU.  The runner sets FAKE_PI_DELAY_MS large so the turn
" stays busy with nothing queued for the whole measurement window.
"
" Dump (/tmp/t-busyhop.txt):
"   HOPS <BufEnter> <WinEnter> <BufLeave>  autocmd firings while busy
"   SPIN <0|1>       the chat's spinner status still advanced
"   FILESTATUS <s>   pi_status leaked onto the file buffer ('' expected)
"   CUR <name>       buffer the cursor ended in (the file)
set nocompatible
set noswapfile
let s:root = fnamemodify(resolve(expand('<sfile>:p')), ':h:h:h')
let g:pi_chat_context_file = 0
let g:pi_chat_session_resume = 0
let g:pi_chat_no_session = 1
execute 'source ' . fnameescape(s:root . '/plugin/pi_chat.vim')

let s:n = {'BufEnter': 0, 'WinEnter': 0, 'BufLeave': 0}
augroup BusyHopProbe
  autocmd!
  autocmd BufEnter * let s:n.BufEnter += 1
  autocmd WinEnter * let s:n.WinEnter += 1
  autocmd BufLeave * let s:n.BufLeave += 1
augroup END

let s:file = '/tmp/t-busyhop-file.txt'
let s:spin0 = ''
function! s:Send()
  for l:w in getwininfo()
    if l:w.bufnr == bufnr('__PiChat__')
      call win_gotoid(l:w.winid)
      break
    endif
  endfor
  call setline('$', 'hello')
  call PiChatSendInput()
  " Go sit in a real file window, like a user editing code mid-turn.
  for l:w in getwininfo()
    if bufname(l:w.bufnr) !~# '^__PiChat'
      call win_gotoid(l:w.winid)
      break
    endif
  endfor
  execute 'silent edit ' . fnameescape(s:file)
  let s:n = map(s:n, '0')
  let s:spin0 = getbufvar(bufnr('__PiChat__'), 'pi_status')
endfunction
function! s:Dump()
  let l:spin1 = getbufvar(bufnr('__PiChat__'), 'pi_status')
  call writefile([
        \ 'HOPS ' . s:n.BufEnter . ' ' . s:n.WinEnter . ' ' . s:n.BufLeave,
        \ 'SPIN ' . (l:spin1 !=# '' && l:spin1 !=# s:spin0 ? 1 : 0),
        \ 'FILESTATUS ' . getbufvar(bufnr(s:file), 'pi_status'),
        \ 'CUR ' . fnamemodify(bufname('%'), ':t'),
        \ ], '/tmp/t-busyhop.txt')
  execute 'qall!'
endfunction
call writefile(['busyhop'], s:file)
call timer_start(300,  { -> execute('silent! PiOpen') })
call timer_start(900,  { -> s:Send() })
call timer_start(3400, { -> s:Dump() })
