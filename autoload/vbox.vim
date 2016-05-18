" autoload/vbox.vim

" CREATION     : 2016-01-14
" MODIFICATION : 2016-05-18
" MAINTAINER   : Kabbaj Amine <amine.kabb@gmail.com>
" LICENSE      : MIT

" Get configuration in s:config where: {{{1
"	.dir               => Templates location
"	.variables         => User variables
"	.empty_buffer_only => Generate template only if current buffer is empty
"	(1)
"	.verbose           => Enable/Disable echo's (0)
"	.edit_split        => Split direction ('rightbelow vertical')
"	.auto_mkdir        => Create templates directory if it does not exist
let s:config = g:vbox
" Ensure that .dir ends with a slash
let s:config.dir = s:config.dir =~# '/$' ? s:config.dir : s:config.dir . '/'
" }}}

function! s:Log(msg, ...) abort " {{{1
	" Echo a formatted a:msg dependig of:
	" a:1: default, 1      , 2
	"      Normal , Warning, Error

	if s:config.verbose
		let l:t = ['Normal', 'WarningMsg', 'Error']
		execute 'echohl ' . (exists('a:1') ? l:t[a:1] : l:t[0] )
					\| echomsg 'vbox: ' . a:msg
					\| echohl None
	endif
endfunction
function! s:CheckBox() abort " {{{1
	if !isdirectory(s:config.dir)
		if s:config.auto_mkdir
			call mkdir(s:config.dir)
		else
			call s:Log(s:config.dir . ' is not a valid directory', 2)
			return 0
		endif
	endif
	return 1
endfunction
" }}}

function! s:ExtendVariables() abort " {{{1
	let l:vars = copy(s:config.variables)
	for [l:k, l:v] in items(l:vars)
		" We evaluate values that start with 'f='
		if l:v =~# '^f='
			let l:vars[l:k] = eval(strpart(l:v, 2))
		endif
	endfor
	return extend(l:vars,
			\ {
				\ '%DATE%'      : strftime('%Y-%m-%d'),
				\ '%EXT%'       : expand('%:e'),
				\ '%FILE%'      : expand('%:t:r'),
				\ '%HOSTNAME%'  : hostname(),
				\ '%TIME%'      : strftime('%H:%M'),
				\ '%USER%'      : $USER
			\ }, 'keep')
endfunction
function! s:ExpandVariables(content) abort " {{{1
	" Replace placeholders in the [list] a:content and returns it.

	let l:content = a:content
	let l:vars = s:ExtendVariables()
	for [l:k, l:v] in items(l:vars)
		call map(l:content, 'substitute(v:val, l:k, l:v, "g")')
	endfor
	return l:content
endfunction
function! s:Goto_(pos) abort " {{{1
	" Set cursor's position to %_% if it exists, otherwise set it to [list]
	" a:pos.

	normal! 1gg
	if search('%_%', 'cw') !=# 0
		normal! "_df%
	else
		call setpos('.', a:pos)
	endif
endfunction
" }}}

function! s:GetTemplatesList() abort " {{{1
	" From s:config.dir return a list containing:
	"  1. A list of file name templates (f=filename)
	"  2. A list of file type templates (=filetype)
	" e.g
	"  [['=f=.tern-project', '=f=readme.md'],
	"  ['=t=javascript', '=t=sh']]

	let l:l = map(
				\ glob(g:vbox.dir . '?=*', 0, 1),
				\ 'fnamemodify(v:val, ":p:t")'
			\ )
	" A 1st list for file name templates...
	let l:f = filter(copy(l:l), 'v:val =~# "^f="')
	" ... and a 2nd one for file type templates
	let l:t = filter(copy(l:l), 'v:val =~# "^t="')

	return [l:f, l:t]
endfunction
function! s:GetTemplateFile(...) abort " {{{1
	" Returns appropriate template file (path + name) if found.
	" a:1 if it exists, is the template file's name given by command
	" completion.
	" If a:2 exists, this function does not check if the temlplate is readable

	let l:l = s:GetTemplatesList()
	if exists('a:1') && !empty(a:1)
		let l:templateName = a:1
		let l:file = 'f=' . a:1
		let l:type = 't=' . a:1
	else
		let l:templateName = ''
		let l:file = 'f=' . expand('%:p:t')
		let l:type = 't=' . &ft
	endif

	let l:indices = [
				\ index(l:l[0], l:file),
				\ index(l:l[1], l:type)
			\ ]

	for l:i in range(0, len(l:indices) - 1)
		if l:indices[l:i] !=# -1
			let l:templateName = get(l:l[l:i], l:indices[l:i])
			break
		endif
	endfor

	" If template's name still empty
	if empty(l:templateName)
		call s:Log('No appropriate template found', 1)
		return 0
	endif

	let l:tf = s:config.dir . l:templateName
	if !exists('a:2')
		if !filereadable(l:tf)
			call s:Log(l:tf . ' is not readable or does not exits', 2)
			return 0
		endif
	endif
	return l:tf
endfunction

function! vbox#Complete(A, L, P) abort " {{{1
	let l:l = s:GetTemplatesList()
	return join(sort(map(l:l[0] + l:l[1], 'strpart(v:val, 2)')), "\n") . "\n"
endfunction
" }}}

function! vbox#PutTemplate(...) abort " {{{1
	if !s:CheckBox()
		return 0
	endif

	if s:config.empty_buffer_only
		if getline(1, line('$')) !=# ['']
			call s:Log('The buffer is not empty', 2)
			return 0
		endif
		let l:toLine = 0
	else
		let l:toLine = (empty(getline('.')) ? line('.') - 1 : line('.'))
	endif

	let l:tf = exists('a:1') ? s:GetTemplateFile(a:1) : s:GetTemplateFile()
	if empty(l:tf)
		return 0
	endif

	let l:pos = getpos('.')
	let l:template = readfile(l:tf)
	call append(l:toLine, s:ExpandVariables(l:template))
	" Delete the last line if its empty (culprit = append())
	if empty(getline(line('$')))
		silent $delete_
	endif
	call s:Goto_(l:pos)

	" Set ft when we're using t=templates.
	if l:tf =~# 't='
		let &ft = matchstr(l:tf, 't=\zs\w*')
	endif

	redraw
endfunction
function! vbox#EditTemplate(...) abort " {{{1
	if !s:CheckBox()
		return 0
	endif

	let l:tf = exists('a:1') ? s:GetTemplateFile(a:1, 1) : s:GetTemplateFile('', 1)
	if !empty(l:tf)
		let l:tn = fnamemodify(l:tf, ':t')
		if l:tn !~# '^\(f\|t\)='
			let l:tt = input("Template's type (t/f): ")
			redraw!
			if l:tt !~# '^\(t\|f\)$'
				call s:Log('Only "f" or "t" are allowed', 2)
				return 0
			endif
			let l:tn = l:tt . '=' . l:tn
		endif
		execute 'silent ' . s:config.edit_split . ' split ' . s:config.dir . l:tn

		" Set ft when we're using t=templates.
		if l:tn =~# '^t='
			let &ft = matchstr(l:tn, 't=\zs\w*')
		endif

		redraw
	endif
endfunction
" }}}

" vim:ft=vim:fdm=marker:fmr={{{,}}}:
