" A simple template engine for vim.

" CREATION     : 2016-01-14
" MODIFICATION : 2016-01-22
" MAINTAINER   : Kabbaj Amine <amine.kabb@gmail.com>
" LICENSE      : MIT

" Vim options {{{1
if exists('g:vbox_loaded')
    finish
endif
let g:vbox_loaded = 1

" To avoid conflict problems.
let s:saveCpoptions = &cpoptions
set cpoptions&vim
" 1}}}

" Configuration {{{1
if !exists('g:vbox')
	let g:vbox = {}
endif
if !has_key(g:vbox, 'dir')
	let g:vbox.dir = ''
endif
if !has_key(g:vbox, 'variables')
	let g:vbox.variables = {}
endif
if !has_key(g:vbox, 'empty_buffer_only')
	let g:vbox.empty_buffer_only = 1
endif
if !has_key(g:vbox, 'verbose')
	let g:vbox.verbose = 1
endif
if !has_key(g:vbox, 'edit_split')
	let g:vbox.edit_split = 'rightbelow vertical'
endif
" }}}

" Commands {{{1
command! -nargs=? -complete=custom,vbox#Complete VBTemplate :call vbox#PutTemplate(<f-args>)
command! -nargs=? -complete=custom,vbox#Complete VBEdit     :call vbox#EditTemplate(<f-args>)
" }}}

" Restore default vim options {{{1
let &cpoptions = s:saveCpoptions
unlet s:saveCpoptions
" 1}}}

" vim:ft=vim:fdm=marker:fmr={{{,}}}:
