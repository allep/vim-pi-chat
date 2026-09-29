" vim: set ft=vim ts=2 sw=2 sts=2 et:
" Scenario: extension `select` dialogs.  Dismissing the list (Esc) must send
" {"cancelled": true}; it used to send the FIRST option, so Esc on pi's own
" example "Allow dangerous command?" [Allow, Block] allowed the command.
" Picking an entry must still send its value.  An `editor` request (not
" supported yet) must be cancelled at once instead of blocking Vim.
"
" The request is fed straight to the plugin's s:UiRequest (resolved through
" its <SNR> prefix) with the answer queued in typeahead first: typeahead is
" not consumed until the callback returns, so inputlist() reads it.  The
" response the plugin sends back is read from the fake's stdin log.
set nocompatible
set noswapfile
let s:root = fnamemodify(resolve(expand('<sfile>:p')), ':h:h:h')
let g:pi_chat_context_file = 0
let g:pi_chat_no_session = 1 " hermetic
let s:log = '/tmp/t-select-stdin.log'
call writefile([], s:log)
execute 'source ' . fnameescape(s:root . '/plugin/pi_chat.vim')
call writefile([], '/tmp/t-select.txt')

let s:snr = matchstr(execute('scriptnames'), '\zs\d\+\ze: [^\n]*plugin/pi_chat.vim')
function! s:Ask(id, keys) abort
  call feedkeys(a:keys, 'n')
  call call('<SNR>' . s:snr . '_UiRequest', [{'type': 'extension_ui_request',
        \ 'id': a:id, 'method': 'select', 'title': 'Allow dangerous command?',
        \ 'options': ['Allow', 'Block']}])
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
function! s:Final() abort
  let l:esc = s:Reply('sel-esc')
  let l:pick = s:Reply('sel-pick')
  let l:ed = s:Reply('ed-1')
  call writefile([
        \ 'esc: ' . json_encode(l:esc),
        \ 'esc-cancelled: ' . (get(l:esc, 'cancelled', v:false) == v:true && !has_key(l:esc, 'value')),
        \ 'pick: ' . json_encode(l:pick),
        \ 'pick-value: ' . get(l:pick, 'value', ''),
        \ 'editor-cancelled: ' . (get(l:ed, 'cancelled', v:false) == v:true),
        \ ], '/tmp/t-select.txt')
  execute 'qall!'
endfunction
call timer_start(300,  { -> execute('silent! PiOpen') })
call timer_start(900,  { -> s:Ask('sel-esc', "\<Esc>") })
call timer_start(1200, { -> s:Ask('sel-pick', "2\<CR>") })
call timer_start(1400, { -> call('<SNR>' . s:snr . '_UiRequest', [{'type': 'extension_ui_request',
      \ 'id': 'ed-1', 'method': 'editor', 'title': 'Edit text', 'prefill': 'x'}]) })
call timer_start(1800, { -> s:Final() })
