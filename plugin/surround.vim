vim9script

# surround.vim - Surroundings
# Author:       Tim Pope <http://tpo.pe/>
# Version:      2.2
# GetLatestVimScripts: 1697 1 :AutoInstall: surround.vim

if exists("g:loaded_surround") || &cp || v:version < 700
  finish
endif
g:loaded_surround = 1

# g:surround_maps = g:->get('surround_maps', {})
# g:surround_maps['-'] = "<% \r %>"
# g:surround_maps['='] = "<%= \r %>"
# g:surround_maps['l'] = "\\begin{\1environment: \1}\r\\end{\1\1}"
# g:surround_maps['l'] = "\\begin{\1environment: \1}\r\\end{\1\r}.*\r\1}"
# g:surround_maps['d'] = "<div\1id: \r..*\r id=\"&\"\1>\r</div>"

import 'surround.vim' as s9

s9.UpgradeSurroundMaps()

nnoremap <silent> <Plug>(surround-repeat) .
nnoremap <silent> <Plug>(surround-d) d
nnoremap <silent> <Plug>(surround-delete) <ScriptCmd>s9.DoSurround(s9.InputTarget())<CR>
nnoremap <silent> <Plug>(surround-change) <ScriptCmd>s9.ChangeSurround()<CR>
nnoremap <silent> <Plug>(surround-change-line) <ScriptCmd>s9.ChangeSurround(true)<CR>
nnoremap <expr>   <Plug>(surround-line) '^' .. v:count1 .. <SID>s9.OpFunc('setup') .. 'g_'
nnoremap <expr>   <Plug>(surround-line-add) <SID>s9.OpFunc2('setup') .. '_'
nnoremap <expr>   <Plug>(surround-add) <SID>s9.OpFunc('setup')
nnoremap <expr>   <Plug>(surround-add-line) <SID>s9.OpFunc2('setup')
vnoremap <silent> <Plug>(surround-visual) <ScriptCmd>s9.OpFunc(visualmode(), visualmode() ==# 'V')<CR>
vnoremap <silent> <Plug>(surround-visual-line) <ScriptCmd>s9.OpFunc(visualmode(), visualmode() !=# 'V')<CR>
inoremap <silent> <Plug>(surround-insert) <C-R>=s9.Insert()<CR>
inoremap <silent> <Plug>(surround-insert-line)  <C-R>=s9.Insert(true)<CR>

if !exists("g:surround_no_mappings") || !g:surround_no_mappings
  nmap ds  <Plug>(surround-delete)
  nmap cs  <Plug>(surround-change)
  nmap cS  <Plug>(surround-change-line)
  nmap ys  <Plug>(surround-add)
  nmap yS  <Plug>(surround-add-line)
  nmap yss <Plug>(surround-line)
  nmap ySs <Plug>(surround-line-add)
  nmap ySS <Plug>(surround-line-add)
  xmap S   <Plug>(surround-visual)
  xmap gS  <Plug>(surround-visual-line)

  if !exists("g:surround_no_insert_mappings") || ! g:surround_no_insert_mappings
    if !hasmapto("<Plug>(surround-insert)", "i") && "" == mapcheck("<C-S>", "i")
      imap    <C-S> <Plug>(surround-insert)
    endif
    imap      <C-G>s <Plug>(surround-insert)
    imap      <C-G>S <Plug>(surround-insert-line)
  endif
endif

augroup vim9-surround-map-upgrade
  autocmd!

  autocmd BufEnter * s9.UpgradeSurroundMaps()
augroup END

# vim:set ft=vim sw=2 sts=2 et:
