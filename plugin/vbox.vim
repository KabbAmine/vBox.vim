" A simple template engine for vim.

" CREATION     : 2016-01-14
" MODIFICATION : 2016-08-17
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

" Commands {{{1
command! -nargs=? -complete=custom,vbox#Complete VBTemplate
			\	call vbox#e('expand', <f-args>)
command! -nargs=? -complete=custom,vbox#Complete VBEdit
			\	call vbox#e('edit', <f-args>)
command! -nargs=1 -complete=custom,vbox#Complete VBDelete
			\	call vbox#e('delete', <f-args>)
" }}}

" Restore default vim options {{{1
let &cpoptions = s:saveCpoptions
unlet s:saveCpoptions
" 1}}}

" vim:ft=vim:fdm=marker:fmr={{{,}}}:
