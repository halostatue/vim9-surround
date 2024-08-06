vim9script

const PAIRS = "b()B{}r[]a<>"

export def InputTarget(): string
  var c = getcharstr()
  while c =~ '^\d+$'
    c ..= getcharstr()
  endwhile

  if c == ' '
    c ..= getcharstr()
  endif

  return c =~ "\<Esc>\|\<C-C>\|\0" ? "" : c
enddef

def InputReplacement(): string
  var c = getcharstr()

  if c =~ '[ 0-9]'
    c ..= getcharstr()
  endif

  return c =~ "\<Esc>|\<C-C>" ? "" : c
enddef

def Beep()
  execute "normal! \<Esc>"
enddef

def Fname(name: string, lisp: bool = false): list<string>
  var lastchar = name->strpart(name->strlen() - 1, 1)
  var lastIdx = PAIRS->stridx(lastchar)

  var cleanName = name->strpart(0, name->strlen() - 1)
  var [charOpen, charClose] = lastIdx >= 0 && lastIdx % 3 == 1
    ? [lastchar, PAIRS->strpart(lastIdx + 1, 1)]
    : ['(', ')']

  return lisp
    ? [printf('%s%s ', charOpen, cleanName), charClose]
    : [printf('%s%s', cleanName, charOpen), charClose]
enddef

def ExtractBefore(str: string): string
  return str =~ '\r' ? matchstr(str, '.*\ze\r') : matchstr(str, '.*\ze\n')
enddef

def ExtractAfter(str: string): string
  return str =~ '\r' ? matchstr(str, '\r\zs.*') : matchstr(str, '\n\zs.*')
enddef

def CustomSurroundings(char: string, d: dict<any>, trim: bool): list<string>
  var all = Process(get(d, printf('surround_%d', char2nr(char))))
  var before = ExtractBefore(all)
  var after = ExtractAfter(all)

  return trim ? [trim(before), trim(after)] : [before, after]
enddef

def FixIndent(str: string, spc: string): string
  var result = str->substitute('\t', repeat(' ', &sw), 'g')
  var spaces = spc->substitute('\t', repeat(' ', &sw), 'g')

  result = result->substitute('\(\n\|\%^\).\@=', '\1' .. spaces, 'g')

  if !&expandtab
    result = result->substitute('\s\{' .. &ts .. '\}', "\t", 'g')
  endif

  return result
enddef

def Process(str: string): string
  var repl: dict<string> = {}

  for i in range(7)
    repl[i] = ''

    var m = matchstr(str, nr2char(i) .. '.\{-\}\ze' .. nr2char(i))

    if m != ''
      m = m->strpart(1)->substitute('\r.*', '', '')
      repl[i] = input(m->match('\w\+$') >= 0 ? m .. ': ' : m)
    endif
  endfor

  var s = ''
  var j = 0

  while j < str->strlen()
    var char = str->strpart(j, 1)

    if char2nr(char) < 8
      var next = str->stridx(char, j + 1)

      if next == -1
        s ..= char
        continue
      endif

      var insertion = repl[char2nr(char)]
      var subs = str
        ->strpart(j + 1, next - j - 1)
        ->matchstr('\r.*')

      while subs =~ '^\r.*\r'
        var sub = subs->matchstr("^\r\\zs[^\r]*\r[^\r]*")
        subs = subs->strpart(sub->strlen() + 1)
        var r = sub->stridx("\r")
        insertion = insertion->substitute(sub->strpart(0, r), sub->strpart(r + 1), '')
      endwhile

      s ..= insertion

      j = next
    else
      s ..= char
    endif

    j += 1
  endwhile

  return s
enddef

var sInput: string = ""
var sLastDel: string = ""

def Wrap(str: string, char: string, wrapType: string, removed: string, linebreak: bool): string
  var keeper = str
  var newchar = char
  var linemode = wrapType ==# 'V'
  var before = ""
  var after = ""
  var initSpaces = linemode ? matchstr(keeper, '\%^\s*') : matchstr(getline('.'), '\%^\s*')
  var scount = 1
  var extraspace = ""

  if newchar =~ '^[0-9]'
    scount = newchar->strpart(0, 1)->str2nr()
    newchar = newchar->strpart(1)
  endif

  if newchar =~ '^ '
    newchar = newchar->strpart(1)
    extraspace = ' '
  endif

  var idx = PAIRS->stridx(newchar)

  var custom = printf('surround_%d', char2nr(newchar))

  if newchar == ' '
    before = ''
    after  = ''
  elseif !b:->get(custom)->empty()
    [before, after] = CustomSurroundings(newchar, b:, false)
  elseif !g:->get(custom)->empty()
    [before, after] = CustomSurroundings(newchar, g:, false)
  elseif newchar ==# "p"
    before = "\n"
    after  = "\n\n"
  elseif newchar ==# 's'
    before = ' '
    after  = ''
  elseif newchar ==# ':'
    before = ':'
    after = ''
  elseif newchar =~# "[tT\<C-T><]"
    var dounmapp = false
    var dounmapb = false

    if !maparg(">", "c")
      dounmapb = true

      # Hide from AsNeeded
      execute printf("cnoremap > ><CR>")
    endif

    var default = ""

    if newchar ==# "T"
      default = sLastDel->matchstr('<\zs.\{-\}\ze>')
    endif

    var tag = input("<", default)

    if dounmapb
      silent! cunmap >
    endif

    sInput = tag
    if tag != ""
      var keepAttributes = tag->match(">$") == -1

      tag = tag->substitute('>*$', '', '')

      var attributes = keepAttributes ? removed->matchstr('<[^ \t\n]\+\zs\_.\{-\}\ze>') : ""

      sInput = tag .. '>'

      if tag =~ '/$'
        tag = tag->substitute('/$', '', '')
        before = printf('<%s%s />', tag, attributes)
        after = ''
      else
        before = printf('<%s%s>', tag, attributes)
        after = printf('</%s>', tag->substitute(' .*', '', ''))
      endif

      if newchar == "\<C-T>"
        if wrapType ==# "v" || wrapType ==# "V"
          before ..= "\n\t"
        endif

        if wrapType ==# "v"
          after = "\n" .. after
        endif
      endif
    endif
  elseif newchar ==# 'l' || newchar == '\'
    # LaTeX
    var env = input('\begin{')

    if env != ""
      sInput = env .. "\<CR>"
      env = printf('{%s%s', env, CloseMatch(env))
      before = printf('\begin%s', env)
      after = printf('\end%s}', env->matchstr('[^}]*'))

      echo before
    endif
  elseif newchar ==# 'f' || newchar ==# 'F'
    var fnf = input('function: ')
    if fnf != ""
      sInput = fnf .. "\<CR>"
      [before, after] = Fname(fnf)

      if newchar ==# 'F'
        before ..= ' '
        after = ' ' .. after
      endif
    endif
  elseif newchar ==# "\<C-F>"
    var fncf = input('function: ')
    sInput = fncf .. "\<CR>"
    [before, after] = Fname(fncf, true)
  elseif idx >= 0
    var spc = (idx % 3) == 1 ? ' ' : ''
    idx = (idx / 3) * 3

    before = PAIRS->strpart(idx + 1, 1) .. spc
    after = spc .. PAIRS->strpart(idx + 2, 1)
  elseif newchar == "\<C-[>" || newchar == "\<C-]>"
    before = "{\n\t"
    after  = "\n}"
  elseif newchar !~ '\a'
    before = newchar
    after  = newchar
  else
    before = ''
    after  = ''
  endif

  if before =~ '.*\n\t$'
    before = repeat(before->substitute('\n\t', '', ''), scount) .. '\n\t'
  else
    before = repeat(before, scount)
  endif

  if after =~ '.*\n\t$'
    after = repeat(after->substitute('\n\t', '', ''), scount) .. '\n\t'
  else
    after = repeat(after, scount)
  endif

  after = after->substitute('\n', '\n' .. initSpaces, 'g')

  if wrapType ==# 'V' || (linebreak && wrapType ==# "v")
    before = before->substitute(' \+$', '', '')
    after  = after->substitute('^ \+', '', '')

    if after !~ '^\n'
      after  = initSpaces .. after
    endif

    if keeper !~ '\n$' && after !~ '^\n'
      keeper ..= "\n"
    elseif keeper =~ '\n$' && after =~ '^\n'
      after = after->strpart(1)
    endif

    if keeper !~ '^\n' && before !~ '\n\s*$'
      before ..= "\n"
      if linebreak
        before ..= "\t"
      endif
    elseif keeper =~ '^\n' && before =~ '\n\s*$'
      keeper = keeper->strcharpart(1)
    endif

    if wrapType ==# 'V' && keeper =~ '\n\s*\n$'
      keeper = keeper->strcharpart(0, keeper->strchars() - 1)
    endif
  endif

  if wrapType ==# 'V'
    before = initSpaces .. before
  endif

  if before =~ '\n\s*\%$'
    if wrapType ==# 'v'
      keeper = initSpaces .. keeper
    endif

    var padding = before
      ->matchstr('\n\zs\s\+\%$')
      ->substitute('\n\s\+\%$', '\n', '')

    keeper = FixIndent(keeper, padding)
  endif

  if wrapType ==# 'V'
    keeper = before .. keeper .. after
  elseif wrapType =~ "^\<C-V>"
    # Really we should be iterating over the buffer
    var repl = printf(
      '%s\\1%s',
      before->substitute('[\\~]', '\\&', 'g'),
      after->substitute('[\\~]', '\\&', 'g')
    )->substitute('\n', ' ', 'g')

    keeper = printf("%s\n", keeper)
      ->substitute('\(.\{-\}\)\(\n\)', repl .. '\n', 'g')
      ->substitute('\n\%$', '', '')
  else
    keeper = before .. extraspace .. keeper .. extraspace .. after
  endif

  return keeper
enddef

def Wrapreg(reg: string, char: string, removed: string, linebreak: bool)
  var orig = reg->getreg()
  var wrapType = reg->getregtype()->substitute('\d\+$', '', '')
  var new = Wrap(orig, char, wrapType, removed, linebreak)

  setreg(reg, new, wrapType)
enddef

def Escape(str: string): string
  return str->escape('!#$%&()*+,-./:;<=>?@[\]^{|}~')
enddef

def DeleteCustom(char: string, d: dict<any>, count: number): list<string>
  var [before, after] = CustomSurroundings(char, d, true)
  var [bpat, apat] = ['\v\C' .. Escape(before), '\v\C' .. Escape(after)]

  # The 'c' flag for searchpair() matches both start and end.
  # Append \zs to the closer pattern so that it doesn't match the closer on the cursor.
  if searchpair(bpat, '', apat .. '\zs', 'bcW') <= 0
    return ['', '']
  endif

  if before !=# after
    for _ in range(count - 1)
      if searchpair(bpat, '', apat, 'bW')
        return ['', '']
      endif
    endfor
  endif

  normal! v

  var found: number

  if before ==# after
    search(bpat, 'ceW')
    found = search(apat, 'eW')
  else
    found = searchpair(bpat, '', apat, 'W')
    search(apat, 'ceW')
  endif

  if found <= 0
    execute "normal! \<Esc>"
    return ['', '']
  endif

  normal! d
  return [before, after]
enddef

export def Insert(wantedLinemode: bool = false): string
  var char = InputReplacement()
  var linemode = wantedLinemode

  while char == "\<CR>" || char == "\<C-S>"
    linemode = true
    char = InputReplacement()
  endwhile

  if char == ""
    return ""
  endif

  var cb_save = &clipboard
  set clipboard-=unnamed clipboard-=unnamedplus

  # how to fix this?
  var reg_save = getreg("@", 1)

  setreg('"', "\032", 'v')
  Wrapreg('"', char, "", linemode)

  # If line mode is used and the surrounding consists solely of a suffix, remove the
  # initial newline. This fits a use case of mine but is a little inconsistent. Is there
  # anyone that would prefer the simpler behavior of just inserting the newline?
  if linemode && match(getreg('"'), '^\n\s*\zs.*') == 0
    setreg('"', matchstr(getreg('"'), '^\n\s*\zs.*'), getregtype('"'))
  endif

  # This can be used to append a placeholder to the end
  if exists("g:surround_insert_tail")
    setreg('"', g:surround_insert_tail, "a" .. getregtype('"'))
  endif

  if &virtualedit != 'all' && col('.') >= col('$')
    if &virtualedit == 'insert'
      var extra_cols = virtcol('.') - virtcol('$')
      if extra_cols > 0
        var [regval, regtype] = [getreg('"', 1, 1), getregtype('"')]
        setreg('"', extra_cols->range()->map('" "')->join(''), 'v')
        normal! ""p
        setreg('"', regval, regtype)
      endif
    endif
    normal! ""p
  else
    normal! ""P
  endif

  if linemode
    Reindent()
  endif

  normal! `]

  search("\032", 'bW')

  setreg("@", reg_save)
  &clipboard = cb_save
  return "\<Del>"
enddef

def Reindent()
  if !b:->get('surround_indent', g:->get('surround_indent', true))
    return
  endif

  if !&equalprg->empty() || !&indentexpr->empty() || &cindent || &smartindent || &lisp
    silent normal! '[=']
  endif
enddef

export def DoSurround(value: string = null_string, new_value: string = null_string, linebreak: bool = false)
  var sol_save = &startofline
  set startofline

  var scount = v:count1
  var char = value == null_string ? InputTarget() : value
  var spc = false

  if char =~ '^\d\+'
    scount = scount * char->matchstr('^\d\+')->str2nr()
    char = char->substitute('^\d\+', '', '')
  endif

  if char =~ '^ '
    char = char->strpart(1)
    spc = true
  endif

  var custom = printf('surround_%d', char2nr(char))

  if b:->get(custom, g:->get(custom))->empty()
    if char == 'a'
      char = '>'
    elseif char == 'r'
      char = ']'
    endif
  endif

  var newchar = ""

  if new_value != null_string
    newchar = new_value

    if newchar == "\<Esc>" || newchar == "\<C-C>" || newchar == ""
      if !sol_save
        set nostartofline
      endif

      Beep()
      return
    endif
  endif

  var cb_save = &clipboard
  set clipboard-=unnamed clipboard-=unnamedplus
  var append = ""
  var original = getreg('"')
  var otype = getregtype('"')
  var before = ""
  var after = ""

  setreg('"', "")

  var strcount = (scount == 1 ? "" : string(scount))

  if char == '/'
    execute 'normal! ' .. strcount .. "[/\<Plug>(surround-d)" .. strcount .. ']/'
  elseif exists(printf('b:surround_%d', char2nr(char)))
    [before, after] = DeleteCustom(char, b:, scount)
  elseif exists(printf('g:surround_%d', char2nr(char)))
    [before, after] = DeleteCustom(char, g:, scount)
  elseif char =~# '[[:punct:][:space:]]' && char !~# '[][(){}<>"''`]'
    execute 'normal! T' .. char
    if getline('.')[col('.') - 1] == char
      execute 'normal! l'
    endif
    execute "normal! \<Plug>(surround-d)t" .. char
  elseif char ==# 'f'
    execute "normal! \<Plug>(surround-d)i(" .. char
  else
    execute "normal \<Plug>(surround-d)" .. strcount .. 'i' .. char
  endif

  var keeper = getreg('"')
  var okeeper = keeper # for reindent below

  if keeper == ""
    setreg('"', original, otype)
    &clipboard = cb_save
    if !sol_save
      set nostartofline
    endif
    return
  endif

  var oldline = getline('.')
  var oldlnum = line('.')

  custom = printf('surround_%d', char2nr(char))

  if !b:->get(custom, g:->get(custom))->empty()
    setreg('"', before .. after, "c")
    keeper = keeper
        ->substitute('\v\C^' .. Escape(before) .. '\s=', '', '')
        ->substitute('\v\C\s=' .. Escape(after) .. '$', '', '')
  elseif char ==# 'p'
    setreg('"', '', 'V')
  elseif char ==# "s" || char ==# "w" || char ==# "W"
    # Do nothing
    setreg('"', '')
  elseif char =~ "[\"'`]"
    execute "normal! i \<Esc>\<Plug>(surround-d)2i" .. char
    setreg('"', substitute(getreg('"'), ' ', '', ''))
  elseif char == '/'
    normal! "_x
    setreg('"', '/**/', "c")
    keeper = keeper
      ->substitute('^/\*\s\=', '', '')
      ->substitute('\s\=\*$', '', '')
  elseif char =~# '[[:punct:][:space:]]' && char !~# '[][(){}<>]'
    execute 'normal! F' .. char
    execute "normal! \<Plug>(surround-d)f" .. char
  else
    # One character backwards
    search('\m.', 'bW')

    if char ==# 'f'
      execute "normal! \<Plug>(surround-d)a(" .. char
      execute 'normal! b\<Plug>(surround-d)w'
      original = getreg('"')
    else
      execute "normal \<Plug>(surround-d)a" .. char
    endif
  endif

  var removed = getreg('"')
  var rem2 = removed->substitute('\n.*', '', '')
  var oldhead = oldline->strpart(0, oldline->strlen() - rem2->strlen())
  var oldtail = oldline->strpart(oldline->strlen() - rem2->strlen())
  var regtype = getregtype('"')

  if char =~# '[\[({<T]' || spc
    keeper = keeper
      ->substitute('^\s\+', '', '')
      ->substitute('\s\+$', '', '')
  endif

  var pcmd = 'p'

  if col("']") == col("$") && virtcol('.') + 1 == virtcol('$')
    if oldhead =~# '^\s*$' && new_value == null_string
      keeper = keeper->substitute('\%^\n' .. oldhead .. '\(\s*.\{-\}\)\n\s*\%$', '\1', '')
    endif
  else
    pcmd = "P"
  endif

  if line('.') + 1 < oldlnum && regtype ==# "V"
    pcmd = "p"
  endif

  setreg('"', keeper, regtype)

  if newchar != ""
    Wrapreg('"', newchar, removed, linebreak)
  endif

  silent execute 'normal! ""' .. pcmd .. '`['

  if removed =~ '\n' || okeeper =~ '\n' || getreg('"') =~ '\n'
    Reindent()
  endif

  if getline('.') =~ '^\s\+$' && keeper =~ '^\s*\n'
    silent normal! cc
  endif

  setreg('"', original, otype)

  sLastDel = removed
  &clipboard = cb_save

  if newchar == ""
    silent! call repeat#set("\<Plug>(surround-delete)" .. char, scount)
  else
    var map = linebreak
        ? "\<Plug>(surround-change-line)%s%s%s"
        : "\<Plug>(surround-change)%s%s%s"

    silent! call repeat#set(printf(map, char, newchar, sInput), scount)
  endif

  if !sol_save
    set nostartofline
  endif
enddef

export def ChangeSurround(linebreak: bool = false)
  var a: string = InputTarget()
  if a == ""
    Beep()
    return
  endif

  var b: string = InputReplacement()
  if b == ""
    Beep()
    return
  endif

  DoSurround(a, b, linebreak)
enddef

export def OpFunc(atype: string, linebreak: bool = false): string
  if atype ==# 'setup'
    &opfunc = OpFunc
    return 'g@'
  endif

  var char = InputReplacement()
  if char == ""
    Beep()
    return ""
  endif

  var reg = '"'
  var sel_save = &selection
  &selection = "inclusive"
  var cb_save  = &clipboard
  set clipboard-=unnamed clipboard-=unnamedplus
  var reg_save = reg->getreg()
  var reg_type = reg->getregtype()
  var type = atype

  if atype == 'char'
    silent execute 'normal v`[o`]"' .. reg .. 'y'
    type = 'v'
  elseif atype == 'line'
    silent execute 'normal `[V`]"' .. reg .. 'y'
    type = 'V'
  elseif atype ==# "v" || atype ==# "V" || atype ==# "\<C-V>"
    &selection = sel_save
    var ve = &virtualedit

    if !linebreak
      set virtualedit=
    endif

    silent execute 'normal! gv"' .. reg .. 'y'
    &virtualedit = ve
  elseif atype =~ '^\d\+$'
    type = 'v'
    silent execute 'normal! ^v' .. atype .. '$h"' .. reg .. 'y'
    if mode() ==# 'v'
      normal! v
      Beep()
      return ""
    endif
  else
    &selection = sel_save
    &clipboard = cb_save
    Beep()
    return ""
  endif

  var append = ""
  var keeper = reg->getreg()

  if type ==# "v" && atype !=# "v"
    append = keeper->matchstr('\_s\@<!\s*$')
    keeper = keeper->substitute('\_s\@<!\s*$', '', '')
  endif

  setreg(reg, keeper, type)
  Wrapreg(reg, char, "", linebreak)

  if type ==# "v" && atype !=# "v" && append != ""
    setreg(reg, append, "ac")
  endif

  silent execute 'normal! gv' .. (reg == '"' ? '' : '"'  ..  reg) .. 'p`['
  if type ==# 'V' || (reg->getreg() =~ '\n' && type ==# 'v')
    Reindent()
  endif

  setreg(reg, reg_save, reg_type)

  &selection = sel_save
  &clipboard = cb_save

  if atype =~ '^\d\+$'
    var map = linebreak
      ? "\<Plug>(surround-add-line)"
      : "\<Plug>(surround-add)"

    silent! call repeat#set(map, char, sInput, atype)
  else
    silent! call repeat#set("\<Plug>(surround-.)" .. char .. sInput)
  endif

  return ""
enddef

export def OpFunc2(atype: string = null_string): string
  if atype ==# 'setup'
    &opfunc = OpFunc2
    return 'g@'
  endif
  return OpFunc(atype, true)
enddef

def CloseMatch(str: string): string
  # Close an open (, {, [, or < on the command line.
  var tail = str->matchstr('.[^\[\](){}<>]*$')

  return tail =~ '^\[.\+'
    ? "]"
    : tail =~ '^(.\+'
    ? ")"
    : tail =~ '^{.\+'
    ? "}"
    : tail =~ '^<.+'
    ? ">"
    : ""
enddef

defcompile
