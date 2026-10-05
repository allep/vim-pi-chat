" vim: set ft=vim ts=2 sw=2 sts=2 et:
" Scenario: stress - a huge thinking stream through the :PiThinking panel.
" Runner env: FAKE_PI_THINKING=1 with FAKE_PI_THINKING_TEXT set to ~3000
" lines (~72k one-char thinking_delta frames).  Pre-fix, every delta forced
" a full panel re-sync (getbufline+compare+setbufline of the whole buffer)
" => O(n^2) work that takes minutes, so this run would still be draining
" when it ends.  Post-fix the panel sync is incremental and the stream
" drains quickly.  The dump carries per-500ms line counts (S1@1.5s, S2@2.0s,
" ...) so the drain profile is visible, plus panel head/tail and chat tail.
set nocompatible
set noswapfile
let s:root = fnamemodify(resolve(expand('<sfile>:p')), ':h:h:h')
let g:pi_chat_context_file = 0
let g:pi_chat_no_session = 1
execute 'source ' . fnameescape(s:root . '/plugin/pi_chat.vim')

let s:out = []
let s:t0 = reltime()
let s:i = 0
augroup StressDebug
  autocmd BufDelete,BufUnload,BufWipeout *
        \ call add(s:out, 'BUFDEL n=' . expand('<abuf>') . ' ' . bufname(expand('<abuf>')))
augroup END
function! s:Sample()
  let s:i += 1
  let l:pb = bufnr('__PiChatThinking__')
  let l:cb = bufnr('__PiChat__')
  let l:relms = float2nr(reltimefloat(s:t0) * 1000)
  let l:tn = (l:pb > 0 && bufloaded(l:pb)) ? len(getbufline(l:pb, 1, '$')) : -1
  let l:cn = l:cb > 0 ? len(getbufline(l:cb, 1, '$')) : -1
  call add(s:out, 'S' . s:i . ' rel=' . l:relms . 'ms think=' . l:tn . ' chat=' . l:cn
        \ . ' win=' . winnr() . ' nwin=' . len(getwininfo()))
  if s:i < 30
    call timer_start(500, { -> s:Sample() })
  endif
endfunction
function! s:Send()
  for l:w in getwininfo()
    if l:w.bufnr == bufnr('__PiChat__')
      call win_gotoid(l:w.winid)
      break
    endif
  endfor
  call setline('$', 'think about it')
  call PiChatSendInput()
endfunction
function! s:Final()
  " Snapshot everything into locals first so no timer can race the read.
  let l:pb = bufnr('__PiChatThinking__')
  let l:cb = bufnr('__PiChat__')
  let l:plines = (l:pb > 0 && bufloaded(l:pb)) ? getbufline(l:pb, 1, '$') : []
  " Negative line numbers are a no-op in this Vim's getbufline; compute
  " the start line from the (single, final) full read instead.
  if l:cb > 0 && bufloaded(l:cb)
    let l:call = getbufline(l:cb, 1, '$')
    let l:clines = l:call[max([0, len(l:call) - 6]) : len(l:call) - 1]
  else
    let l:clines = []
  endif
  call add(s:out, 'STATE pb=' . l:pb . ' cb=' . l:cb
        \ . ' pbloaded=' . (l:pb > 0 ? bufloaded(l:pb) : -1)
        \ . ' cbloaded=' . (l:cb > 0 ? bufloaded(l:cb) : -1))
  call add(s:out, 'PANELCOUNT ' . len(l:plines))
  if !empty(l:plines)
    call add(s:out, 'PANELHEAD ' . l:plines[0])
    call add(s:out, 'PANELTAIL ' . l:plines[-1])
  endif
  for l:l in l:clines
    call add(s:out, 'CHATTAIL ' . l:l)
  endfor
  try
    call writefile(s:out, '/tmp/t-stress.txt')
  catch
    call writefile(['DUMP FAILED: ' . v:exception], '/tmp/t-stress.txt')
  endtry
  execute 'qall!'
endfunction
call timer_start(300,  { -> execute('silent! PiOpen') })
call timer_start(1000, { -> s:Send() })
call timer_start(1500, { -> s:Sample() })
call timer_start(18500, { -> s:Final() })
