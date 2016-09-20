" autoload/vbox.vim

" CREATION     : 2016-01-14
" MODIFICATION : 2016-09-20
" MAINTAINER   : Kabbaj Amine <amine.kabb@gmail.com>
" LICENSE      : MIT

" Main dictionary
let s:vbox = {}

function! s:vbox.log(msg, ...) abort " {{{1
	" Echo a formatted a:msg dependig of:
	" a:1: default, 1      , 2
	"      Normal , Warning, Error

	if self.config['verbose']
		let l:t = ['Normal', 'WarningMsg', 'Error']
		execute 'echohl ' . (exists('a:1') ? l:t[a:1] : l:t[0] )
					\| echomsg 'vbox: ' . a:msg
					\| echohl None
	endif
endfunction
function! s:vbox.setConfig() abort " {{{1
	if !exists('g:vbox')
		let g:vbox = {}
	endif
	let g:vbox.dir = get(g:vbox, 'dir', '')
	let g:vbox.variables = get(g:vbox, 'variables', {})
	let g:vbox.empty_buffer_only = get(g:vbox, 'empty_buffer_only', 1)
	let g:vbox.verbose = get(g:vbox, 'verbose', 1)
	let g:vbox.edit_split = get(g:vbox, 'edit_split', 'rightbelow vertical')
	let g:vbox.auto_mkdir = get(g:vbox, 'auto_mkdir', 1)

	let self.config = g:vbox

	" Ensure that .dir ends with a slash
	let self.config['dir'] = self.config['dir'] =~# '/$' ?
				\	self.config['dir'] : self.config['dir'] . '/'
endfunction
function! s:vbox.checkBox() abort " {{{1
	let l:d = self.config['dir']
	if !isdirectory(l:d)
		if self.config['auto_mkdir']
			call mkdir(l:d)
		else
			call self.log(l:d . ' is not a valid directory', 2)
			return
		endif
	endif
	return 1
endfunction
function! s:vbox.extendVariables() abort " {{{1
	let l:vars = copy(self.config['variables'])
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
function! s:vbox.expandVariables(content) abort " {{{1
	" Replace placeholders in the [list] a:content and returns it.

	let l:content = a:content
	let l:vars = self.extendVariables()
	for [l:k, l:v] in items(l:vars)
		call map(l:content, 'substitute(v:val, l:k, l:v, "g")')
	endfor
	return l:content
endfunction
function! s:vbox.getTemplatesList() abort " {{{1
	" From self.dir return a list containing:
	"  1. A list of file name templates (f=filename)
	"  2. A list of file type templates (=filetype)
	" e.g
	"  [['=f=.tern-project', '=f=readme.md'],
	"  ['=t=javascript', '=t=sh']]

	let l:l = map(
				\ glob(self.config['dir'] . '?=*', 0, 1),
				\ 'fnamemodify(v:val, ":p:t")'
			\ )
	" A 1st list for file name templates...
	let l:f = filter(copy(l:l), 'v:val =~# "^f="')
	" ... and a 2nd one for file type templates
	let l:t = filter(copy(l:l), 'v:val =~# "^t="')

	return [l:f, l:t]
endfunction
function! s:vbox.getTemplateFile(...) abort " {{{1
	" Returns appropriate template file (path + name) if found.
	" a:1 if it exists, is the template file's name given by command
	" completion.
	" If a:2 exists, this function does not check if the template is readable

	let l:l = self.getTemplatesList()
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
		call self.log('No appropriate template found', 1)
		return
	endif

	let l:tf = self.config['dir'] . l:templateName
	if !exists('a:2')
		if !filereadable(l:tf)
			call self.log(l:tf . ' is not readable or does not exits', 2)
			return
		endif
	endif
	return l:tf
endfunction
function! s:vbox.expandTemplate(...) abort " {{{1
	if !self.checkBox()
		return
	endif

	if self.config['empty_buffer_only']
		if getline(1, line('$')) !=# ['']
			call self.log('The buffer is not empty', 2)
			return
		endif
		let l:toLine = 0
	else
		let l:toLine = (empty(getline('.')) ? line('.') - 1 : line('.'))
	endif

	let l:tf = exists('a:1') ?
				\	self.getTemplateFile(a:1) : self.getTemplateFile()
	if empty(l:tf)
		return
	endif

	let l:pos = getpos('.')
	let l:template = readfile(l:tf)
	call append(l:toLine, self.expandVariables(l:template))
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
function! s:vbox.editTemplate(...) abort " {{{1
	if !self.checkBox()
		return
	endif

	let l:cfg = self.config

	let l:tf = exists('a:1') ?
				\	self.getTemplateFile(a:1, 1) : self.getTemplateFile('', 1)
	if !empty(l:tf)
		let l:tn = fnamemodify(l:tf, ':t')
		if l:tn !~# '^\(f\|t\)='
			let l:tt = input("Template's type (t/f): ")
			redraw!
			if l:tt !~# '^\(t\|f\)$'
				call self.log('Only "f" or "t" are allowed', 2)
				return
			endif
			let l:tn = l:tt . '=' . l:tn
		endif
		execute 'silent ' . l:cfg['edit_split'] . ' split ' . l:cfg.dir . l:tn

		" Set ft when we're using t=templates.
		if l:tn =~# '^t='
			let &ft = matchstr(l:tn, 't=\zs\w*')
		endif

		redraw
	endif
endfunction
function! s:vbox.deleteTemplate(template) abort " {{{1
	if empty(a:template)
		return
	endif

	if !self.checkBox()
		return
	endif

	let l:cfg = self.config

	let l:tf = self.getTemplateFile(a:template)
	if l:tf ==# '0'
		return
	endif

	if delete(l:tf) ==# 0
		call self.log(l:tf . ' was successfully deleted')
	else
		call self.log('Something went wrong, ' . l:tf . ' was not deleted', 2)
	endif
endfunction
" }}}

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
" 1}}}

function! vbox#e(action, ...) abort " {{{1
	let l:v = s:vbox
	call l:v.setConfig()

	let l:arg = get(a:, '1', '')

	if a:action ==# 'expand'
		call l:v.expandTemplate(l:arg)
	elseif a:action ==# 'delete'
		call l:v.deleteTemplate(l:arg)
	elseif a:action ==# 'edit'
		call l:v.editTemplate(l:arg)
	endif
endfunction
function! vbox#Complete(A, L, P) abort " {{{1
	let l:v = s:vbox
	call l:v.setConfig()
	let l:l = l:v.getTemplatesList()
	return join(sort(map(l:l[0] + l:l[1], 'strpart(v:val, 2)')), "\n") . "\n"
endfunction
" }}}

" vim:ft=vim:fdm=marker:fmr={{{,}}}:
