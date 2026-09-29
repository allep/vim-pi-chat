" vim: set ft=vim ts=2 sw=2 sts=2 et:
" Scenario: :PiClear on a file that INHERITED its folder's conversation.
" The file has no session of its own, so :PiOpen resumes the folder session
" (kind 'dir').  :PiClear used to delete that folder session file - the
" conversation every other file in the folder inherits.  Now it must leave the
" folder session alone and give the file its own fresh session id.
set nocompatible
set noswapfile
let s:root = fnamemodify(resolve(expand('<sfile>:p')), ':h:h:h')
let s:argv = '/tmp/t-cleardir-argv.log'
call writefile([], s:argv)
let s:sess = '/tmp/t-cleardir-sess'
call delete(s:sess, 'rf')
let g:pi_chat_session_dir = s:sess

let s:dir = resolve(tempname()) . '-cleardir'
call mkdir(s:dir, 'p')
let s:file = s:dir . '/notes.txt'
call writefile(['notes'], s:file)

" Same formula as the plugin's s:DeriveSessionId.
function! s:Sid(path) abort
  let l:p = resolve(fnamemodify(a:path, ':p'))
  let l:p = len(l:p) > 1 ? substitute(l:p, '/$', '', '') : l:p
  return printf('pchat-%d-%s', strlen(l:p), sha256(l:p))
endfunction
let s:dir_id = s:Sid(s:dir)
let s:file_id = s:Sid(s:file)
let s:dir_session = s:sess . '/--dir--/2026-01-01T00-00-00-000Z_' . s:dir_id . '.jsonl'
call mkdir(fnamemodify(s:dir_session, ':h'), 'p')
call writefile([
      \ '{"type":"message","message":{"role":"user","content":"folder question"}}',
      \ '{"type":"message","message":{"role":"assistant","content":[{"type":"text","text":"folder answer"}]}}',
      \ ], s:dir_session)

execute 'silent edit ' . fnameescape(s:file)
execute 'source ' . fnameescape(s:root . '/plugin/pi_chat.vim')
call writefile([], '/tmp/t-cleardir.txt')

function! s:Ids() abort
  let l:ids = []
  for l:ln in readfile(s:argv)
    let l:args = json_decode(l:ln)
    let l:i = index(l:args, '--session-id')
    call add(l:ids, l:i < 0 ? '' : l:args[l:i + 1])
  endfor
  return l:ids
endfunction
function! s:Final() abort
  let l:ids = s:Ids()
  let l:chat = getbufline(bufnr('__PiChat__'), 1, 100000)
  let l:out = ['launches: ' . len(l:ids)]
  call add(l:out, 'resumed-dir: ' . (get(l:ids, 0, '') ==# s:dir_id))
  call add(l:out, 'clear-id-is-file: ' . (get(l:ids, 1, '') ==# s:file_id))
  call add(l:out, 'dir-session-kept: ' . filereadable(s:dir_session))
  call writefile(l:out + l:chat, '/tmp/t-cleardir.txt')
  execute 'qall!'
endfunction
call timer_start(300,  { -> execute('silent! PiOpen') })
call timer_start(1000, { -> execute('silent! PiClear') })
call timer_start(1800, { -> s:Final() })
