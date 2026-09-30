" vim: set ft=vim ts=2 sw=2 sts=2 et:
" Scenario: extension UI dialogs (rpc-extension-ui.md).
"   select   Esc sends {"cancelled": true} - it used to send the FIRST option,
"            so Esc on "Allow dangerous command?" [Allow, Block] allowed it;
"            a pick sends its value; a single option is still asked.
"   confirm  Yes -> confirmed true, No -> false, dismissed -> cancelled, and
"            the prompt shows title AND message.  (Console confirm() discards
"            typeahead, so its answer mapping and text are checked directly.)
"   input    typed text is the value (the placeholder is a hint, never
"            pre-filled); Enter on an empty line sends ''; Esc -> cancelled.
"   editor   not supported yet: cancelled at once instead of blocking Vim.
"   setStatus (fire-and-forget) gets NO reply; its text shows in the chat
"            statusline until cleared.
"   set_editor_text prefills the ❯ prompt (multi-line: continuation lines).
" Every reply must carry the id of the request it answers (s:Send used to
" overwrite it with a req-N id, so pi never matched any dialog answer).
"
" Each request is fed straight to the plugin's s:UiRequest (resolved through
" its <SNR> prefix) with the answer queued in typeahead first: typeahead is
" not consumed until the callback returns, so the prompt reads it.  Replies
" are read back from the fake's stdin log.
set nocompatible
set noswapfile
let s:root = fnamemodify(resolve(expand('<sfile>:p')), ':h:h:h')
let g:pi_chat_context_file = 0
let g:pi_chat_no_session = 1 " hermetic
let s:log = '/tmp/t-dialogs-stdin.log'
call writefile([], s:log)
execute 'source ' . fnameescape(s:root . '/plugin/pi_chat.vim')
call writefile([], '/tmp/t-dialogs.txt')

let s:snr = matchstr(execute('scriptnames'), '\zs\d\+\ze: [^\n]*plugin/pi_chat.vim')
function! s:Ask(keys, req) abort
  if a:keys !=# ''
    " 't': handle the keys as if typed - a NON-typed <Esc> on the command
    " line executes it instead of aborting (:help c_<Esc>).
    call feedkeys(a:keys, 'nt')
  endif
  call call('<SNR>' . s:snr . '_UiRequest',
        \ [extend({'type': 'extension_ui_request'}, a:req)])
endfunction
function! s:Reply(id) abort
  for l:ln in readfile(s:log)
    let l:m = json_decode(l:ln)
    if get(l:m, 'type', '') ==# 'extension_ui_response' && get(l:m, 'id', '') ==# a:id
      return l:m
    endif
  endfor
  return {}
endfunction
function! s:Cancelled(id) abort
  let l:r = s:Reply(a:id)
  return get(l:r, 'cancelled', v:false) == v:true && !has_key(l:r, 'value')
        \ && !has_key(l:r, 'confirmed')
endfunction
function! s:Final() abort
  let l:pick = s:Reply('sel-pick')
  let l:F = { name, args -> call('<SNR>' . s:snr . '_' . name, args) }
  let l:text = s:Reply('in-text')
  let l:empty = s:Reply('in-empty')
  call writefile([
        \ 'sel-esc-cancelled: ' . s:Cancelled('sel-esc'),
        \ 'sel-pick-value: ' . get(l:pick, 'value', '?'),
        \ 'sel-one-cancelled: ' . s:Cancelled('sel-one'),
        \ 'conf-yes: ' . json_encode(l:F('ConfirmPayload', [1])),
        \ 'conf-no: ' . json_encode(l:F('ConfirmPayload', [2])),
        \ 'conf-esc: ' . json_encode(l:F('ConfirmPayload', [0])),
        \ 'conf-text: ' . json_encode(l:F('DialogText', [{'title': 'Clear session?',
        \   'message': 'All messages will be lost.'}, 'Confirm?'])),
        \ 'in-text-value: [' . get(l:text, 'value', '?') . ']',
        \ 'in-empty-value: [' . get(l:empty, 'value', '?') . ']',
        \ 'in-esc-cancelled: ' . s:Cancelled('in-esc'),
        \ 'editor-cancelled: ' . s:Cancelled('ed-1'),
        \ 'status-replied: ' . !empty(s:Reply('st-1')),
        \ 'status-shown: ' . (s:status_set =~# 'indexing 3 files'),
        \ 'status-cleared: ' . (s:status_cleared !~# 'indexing'),
        \ 'prompt-prefill: ' . join(getbufline(bufnr('__PiChat__'), 1, '$')[-2:], '|'),
        \ ], '/tmp/t-dialogs.txt')
  execute 'qall!'
endfunction
let s:sel = {'method': 'select', 'title': 'Allow dangerous command?', 'options': ['Allow', 'Block']}
call timer_start(300,  { -> execute('silent! PiOpen') })
call timer_start(900,  { -> s:Ask("\<Esc>", extend({'id': 'sel-esc'}, s:sel)) })
call timer_start(1000, { -> s:Ask("2\<CR>", extend({'id': 'sel-pick'}, s:sel)) })
call timer_start(1100, { -> s:Ask("\<Esc>", {'id': 'sel-one', 'method': 'select', 'title': 'Proceed?', 'options': ['Yes, run it']}) })
call timer_start(1400, { -> s:Ask("abc\<CR>", {'id': 'in-text', 'method': 'input', 'title': 'Name', 'placeholder': 'hint'}) })
call timer_start(1500, { -> s:Ask("\<CR>", {'id': 'in-empty', 'method': 'input', 'title': 'Name', 'placeholder': 'hint'}) })
call timer_start(1600, { -> s:Ask("\<Esc>", {'id': 'in-esc', 'method': 'input', 'title': 'Name'}) })
call timer_start(1700, { -> s:Ask('', {'id': 'ed-1', 'method': 'editor', 'title': 'Edit text', 'prefill': 'x'}) })
call timer_start(1800, { -> s:Ask('', {'id': 'st-1', 'method': 'setStatus', 'statusKey': 'k', 'statusText': 'indexing 3 files'}) })
let s:status_set = ''
let s:status_cleared = ''
function! s:StatusSnap(which) abort
  execute 'let s:status_' . a:which . ' = PiChatStatusText()'
endfunction
call timer_start(1900, { -> s:StatusSnap('set') })
call timer_start(2000, { -> s:Ask('', {'id': 'st-2', 'method': 'setStatus', 'statusKey': 'k'}) })
call timer_start(2100, { -> s:StatusSnap('cleared') })
call timer_start(2200, { -> s:Ask('', {'id': 'ed-2', 'method': 'set_editor_text', 'text': "prefilled\nsecond line"}) })
call timer_start(2600, { -> s:Final() })
