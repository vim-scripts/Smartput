" Vim global plugin -- test script around the "smartput" topic
"
" General: {{{1
" From Vim7's todo list (see :help todo):
" Smart cut/paste: Recognize words and adjust spaces before/after them.
"
" File:		smartput.vim
" Last Change:	2007 Dec 17
" Version:	0.6
" Vim Version:	Vim7
" Author:	Andy Wokula, anwoku#yahoo*de (#* -> @.)
"
" Description: {{{1
" see doc/smartput.vim
"
" Installation: {{{1
" copy file to your plugin folder
" }}}

" Script Start:
" Script Init Folklore: {{{1
if exists("loaded_smartput")
    finish
endif
let loaded_smartput = 1

if v:version < 700 || &cp
    echo "Smartput: you need at least Vim 7.0"
    finish
endif

let cpo_save = &cpo
set cpo&vim

" Global Defaults: {{{1
let g:smartput_keyword = '\k'
let g:smartput_comma = ','
let g:smartput_flipcomma = '(, ,) s, ,e ,. ,! ,? ,,'
let g:smartput_types = "\t".'s s [({<( ])}>) ,;,'
let g:smartput_app1 = ',.!?:'
let g:smartput_ins2 = 'kk k( )k /k )('
let g:smartput_keep2 = ",e .e !e ?e :e"
let g:smartput_keep2 .= " ,, ., ,\t ;\t"
" }}}

" Functions:
" s:CharType: group chars to CharTypes {{{1
" Predefined: b k s e
function! CharType(char)
    if a:char == '\' | return 'b' | endif
    if a:char =~ s:smartput_keyword | return "k" | endif
    let type = matchstr(s:smartput_types, '\V'.a:char.'\S\*\zs\S')
    return type=="" ? a:char : type
endfunction

" s:FlipAdvice: check if a comma should change sides in the put {{{1
function! s:FlipAdvised(LCP, RPC)
    " LCP, RPC: LC.LP, RP.RC (one of [LP, RP] is a comma)
    let ldc = stridx(s:smartput_flipcomma, a:LCP) >= 0	" left deny comma
    let rdc = stridx(s:smartput_flipcomma, a:RPC) >= 0	" right deny comma
    return !ldc && rdc || ldc && !rdc
    " 'deny comma': comma not allowed here, force flipping to other side
    " don't flip if comma allowed/denied on both sides
endfunction

" s:NeedSpace: check two chars whether they need a space in between {{{1
function! s:NeedSpace(cl, cr)
    if stridx(s:smartput_app1, a:cl) >= 0
	return stridx(s:smartput_keep2, a:cl.a:cr) < 0
    else
	return stridx(s:smartput_ins2, a:cl.a:cr) >= 0
    endif
endfunction

" s:BGval: get a variable's buffer-local or global value {{{1
function! s:BGval(varname)
    return exists("b:".a:varname) ? {"b:".a:varname} : {"g:".a:varname}
endfunction

" Smartput: recognize words and adjust spaces and commas {{{1
function! <sid>Smartput(putcmd)
    " putcmd: "P", "p", "gP" or "gp"
    let l:count = v:count1
    let reg = v:register
    if !s:enable || getregtype(reg) !=# 'v' || v:register =~ '[:.%#=_]'
	exe "nn <sid>put" l:count.'"'.reg.a:putcmd
	return
    endif
    let put = getreg(reg)

    " keep the "xp" trick working:
    if put =~ "^.$"
	exe "nn <sid>put" l:count.'"'.reg.a:putcmd
	return
    endif

    let put = substitute(put, '^\s*\|\s*$', '', 'g')
    if put == ""
	nn <sid>put <nop>
	return
    endif

    let s:smartput_app1 = s:BGval("smartput_app1")
    let s:smartput_comma = s:BGval("smartput_comma")
    let s:smartput_flipcomma = s:BGval("smartput_flipcomma")
    let s:smartput_ins2 = s:BGval("smartput_ins2")
    let s:smartput_keep2 = s:BGval("smartput_keep2")
    let s:smartput_keyword = s:BGval("smartput_keyword")
    let s:smartput_types = s:BGval("smartput_types")

    let putcmd = a:putcmd
    let nogput = a:putcmd[-1:]

    let curcol = col(".") - 1
    let curlnum = line(".")
    let line = getline(curlnum)
    let toofar = 0
    if nogput ==# "p"
	let lencac = strlen(matchstr(line, ".", curcol))
	" len of char at cursor
	let curcol += lencac
	let toofar = lencac
    endif
    let leftcursor = strpart(line, 0, curcol)
    if virtcol(".") >= virtcol("$") && virtcol(".") > 1
	" cope with 'virtualedit=all'
	let nxspaces = virtcol(".")-virtcol("$")    " without +1 ?
	let leftcursor .= repeat(" ", nxspaces)
	let curcol += nxspaces
	let rightcursor = ""
    else
	let rightcursor = strpart(line, curcol)
	if rightcursor[0] =~ '\s'
	    let rightcursor = substitute(rightcursor, '^\s*', '','')
	endif
    endif

    " get the 4 characters at cut points
    if leftcursor =~ '^\s*$'
	let LC = "s"	" Left Cursor, CharType start-of-line
    else
	let LC = CharType(matchstr(leftcursor, ".$"))
	" keep whitespace left from cursor
    endif
    if rightcursor == ""
	let RC = "e"	" Right Cursor, CharType end-of-line
	if &virtualedit != "all"
	    let putcmd = tolower(putcmd)
	    let toofar = 1  " needed?
	endif
    else
	let RC = CharType(matchstr(rightcursor, "^."))
    endif
    let lpchar = matchstr(put, "^.")
    let LP = CharType(lpchar)
    let rpchar = matchstr(put, ".$")
    let RP = CharType(rpchar)

    if stridx(s:smartput_comma, LP)>=0 && s:FlipAdvised(LC.LP, RP.RC)
	" move comma to end of put
	let oldRP = RP
	let RP = LP
	let put = substitute(put, '^.\s*', '','')
	let put = put . " "[!s:NeedSpace(oldRP, RP)] . lpchar
	let LP = CharType(matchstr(put, "^."))
    elseif stridx(s:smartput_comma, RP)>=0 && s:FlipAdvised(LC.LP, RP.RC)
	" move comma to start of put
	let oldLP = LP
	let LP = RP
	let put = substitute(put, '\s*.$', '','')
	let put = rpchar . " "[!s:NeedSpace(LP, oldLP)] . put
	let RP = CharType(matchstr(put, ".$"))
    endif

    let asusual = 1
    let needspaceleft = s:NeedSpace(LC, LP)
    let needspaceright = s:NeedSpace(RP, RC)
    if needspaceleft
	if needspaceright
	    let rightcursor = " " . rightcursor
	endif
	let put = " " . put
    elseif needspaceright
	let put = put . " "
    elseif l:count > 1 && s:NeedSpace(RP, LP)
	let asusual = 0
    endif

    call setline(curlnum, leftcursor . rightcursor)
    call cursor(curlnum, curcol+1-toofar)
    call setreg(reg, put)
    if asusual
	exe "nn <sid>put" l:count.'"'.reg.putcmd
    else
	" e.g. 3p -> p2p, 3P -> P2p, 3gp -> p2gp, 3gP -> P2gp
	exe 'nn <sid>pone' '"'.reg.nogput."`]"
	" recursive call
	exe 'nmap <sid>put <sid>pone'.(l:count-1).'"'.reg.tolower(putcmd)
    endif
endfunction

" SmartputToggle: toggle mapping of P, p, gP, gp {{{1
function! s:SmartputToggle(arg)
    " arg: "on":enable, "off":disable, "":toggle,
    "	"bufoff":turn off for buffer, "bufon":turn on for buffer
    let msg = 0
    if a:arg == "on"
	let s:enable = 1
    elseif a:arg == "off"
	let s:enable = 0
    elseif a:arg == ""
	let s:enable = !s:enable
	let msg = 1
    elseif a:arg == "bufon"
	sil! nun <buffer> P
	sil! nun <buffer> p
	sil! nun <buffer> gP
	sil! nun <buffer> gp
	return
    elseif a:arg == "bufoff"
	nn <buffer> P P
	nn <buffer> p p
	nn <buffer> gP gP
	nn <buffer> gp gp
	return
    elseif a:arg == "stats"
	echo "Status:" (s:enable ? "on" : "off") (maparg("p")=="p" ? "bufoff" : "bufon")
	return
    else
	echomsg 'SmartputToggle: valid args are on, off, bufon, bufoff, <empty>, stats'
	return
    endif
    if s:enable
	nn <script><silent> P  :<c-u>call<sid>Smartput('P')<cr><sid>put
	nn <script><silent> p  :<c-u>call<sid>Smartput('p')<cr><sid>put
	nn <script><silent> gP :<c-u>call<sid>Smartput('gP')<cr><sid>put
	nn <script><silent> gp :<c-u>call<sid>Smartput('gp')<cr><sid>put
	" XXX using <expr> would be much easier but exclude too many older
	" Vim7s with the count bug
    else
	sil! nun P
	sil! nun p
	sil! nun gP
	sil! nun gp
    endif
    if msg
	echo "Smartput" s:enable ? "on" : "off"
    endif
endfunction

func! s:SmaToCompl(lead, cmdl, cpos)
    return "on\noff\nbufon\nbufoff\nstats"
endfunc
" }}}

" Commands, Mappings, Inits: {{{1
com! -bar -nargs=? -complete=custom,s:SmaToCompl SmartputToggle call s:SmartputToggle(<q-args>)
nn <plug>SmartputToggle :SmartputToggle<cr>

if !hasmapto("<plug>SmartputToggle", "n")
    try
	nmap <unique> <leader>st <plug>SmartputToggle
    catch /./
	au VimEnter * echomsg "Smartput:"
		    \"You should map a key to <Plug>SmartputToggle in your vimrc"
    endtry
endif

if !exists("g:smartput") || g:smartput
    let s:enable = 1
    SmartputToggle on
else
    let s:enable = 0
endif

" Cleanup: {{{1
let &cpo = cpo_save

" Modeline: {{{1
" vim:set fdm=marker fdc=2 ts=8:
