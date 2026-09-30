" vim: set ft=vim ts=2 sw=2 sts=2 et:
" Scenario: how a resumed session is rendered.
"   - prompts show what the user typed: the plugin's injected context prefix
"     ('The file I am working on is: ...' / 'I switched ... to: ...') is
"     stripped again, and each prompt gets the live chat's blank separator;
"   - an old-style bare switch notice (a whole prompt of its own) renders as
"     the chat's 'context file switched' line, not as a ❯ prompt;
"   - only the ACTIVE branch is shown: pi sessions are a tree (id/parentId)
"     and the abandoned branch below must not leak into chat or panel;
"   - the thinking panel's '────' markers carry the stripped prompt too.
set nocompatible
set noswapfile
let s:root = fnamemodify(resolve(expand('<sfile>:p')), ':h:h:h')
let s:sess = '/tmp/t-resumefmt-sess'
call delete(s:sess, 'rf')
let g:pi_chat_session_dir = s:sess

let s:dir = resolve(tempname()) . '-resumefmt'
call mkdir(s:dir, 'p')
let s:ctx = s:dir . '/f.txt'
call writefile(['f'], s:ctx)
function! s:Sid(path) abort
  let l:p = resolve(fnamemodify(a:path, ':p'))
  let l:p = len(l:p) > 1 ? substitute(l:p, '/$', '', '') : l:p
  return printf('pchat-%d-%s', strlen(l:p), sha256(l:p))
endfunction

function! s:Msg(id, parent, role, content) abort
  return json_encode({'type': 'message', 'id': a:id,
        \ 'parentId': a:parent ==# '' ? v:null : a:parent,
        \ 'message': {'role': a:role, 'content': a:content}})
endfunction
let s:edit_hint = ' (read it if you need its contents; edit it in place when asked).'
let s:sfile = s:sess . '/--fmt--/2026-01-01T00-00-00-000Z_' . s:Sid(s:ctx) . '.jsonl'
call mkdir(fnamemodify(s:sfile, ':h'), 'p')
call writefile([
      \ json_encode({'type': 'session', 'version': 3, 'id': 'u'}),
      \ s:Msg('a1', '', 'user', 'The file I am working on is: /x/f.txt' . s:edit_hint . "\nfirst question"),
      \ s:Msg('a2', 'a1', 'assistant', [{'type': 'text', 'text': 'first answer'}]),
      \ s:Msg('b1', 'a2', 'user', 'abandoned question'),
      \ s:Msg('b2', 'b1', 'assistant', [{'type': 'thinking', 'thinking': 'abandoned thought'},
      \                                 {'type': 'text', 'text': 'abandoned answer'}]),
      \ s:Msg('c1', 'a2', 'user', 'I switched the file I am working on to: /x/g.txt (read it if you need its contents).'),
      \ s:Msg('c2', 'c1', 'user', 'I switched the file I am working on to: /x/g.txt' . s:edit_hint . "\nsecond question\nwith two lines"),
      \ s:Msg('c3', 'c2', 'assistant', [{'type': 'thinking', 'thinking': 'kept thought'},
      \                                 {'type': 'text', 'text': 'second answer'}]),
      \ ], s:sfile)

execute 'silent edit ' . fnameescape(s:ctx)
execute 'source ' . fnameescape(s:root . '/plugin/pi_chat.vim')
call writefile([], '/tmp/t-resumefmt.txt')

function! s:Final() abort
  let l:chat = getbufline(bufnr('__PiChat__'), 1, '$')
  let l:panel = getbufline(bufnr('__PiChatThinking__'), 1, '$')
  let l:i = index(l:chat, '❯ first question')
  let l:out = ['blank-before-first: ' . (l:i > 0 && l:chat[l:i - 1] ==# '')]
  call writefile(l:out + map(l:chat, '"CHAT " . v:val') + map(l:panel, '"PANEL " . v:val'),
        \ '/tmp/t-resumefmt.txt')
  execute 'qall!'
endfunction
call timer_start(300,  { -> execute('silent! PiOpen') })
call timer_start(1500, { -> s:Final() })
