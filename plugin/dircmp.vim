" File: dircmp.vim
" Author: YuChang <yuchang668@outlook.com>
" Website: https://github.com/yuchang668
" License: Apache License, Version 2.0
" Description: directory compare

if exists('loaded_dircmp') || v:version < 802 || v:version == 801 && (!has('patch0037') || !has('patch0039')) || &compatible | finish | endif
let loaded_dircmp = 1

let s:cpo_save = &cpo
set cpo&vim

function s:dircmp(...)
    if a:0 != 2 || !empty(filter(a:000[0:1], {_,path -> !isdirectory(path) && !filereadable(path)})) | return | endif
    return dircmp#exec(a:1, a:2)
endfunction

command -nargs=* -complete=file Dircmp call s:dircmp(<f-args>)

highlight DircmpSignEqual       ctermbg=darkgreen     guibg=darkgreen
highlight DircmpSignDiffer      ctermbg=darkred       guibg=darkred
highlight DircmpSignExcess      ctermbg=darkblue      guibg=darkblue
highlight DircmpSignConflict    ctermbg=darkyellow    guibg=darkyellow

highlight DircmpTextEqual       ctermfg=darkgreen     guifg=darkgreen
highlight DircmpTextDiffer      ctermfg=darkred       guifg=darkred
highlight DircmpTextExcess      ctermfg=darkblue      guifg=darkblue
highlight DircmpTextConflict    ctermfg=darkyellow    guifg=darkyellow

highlight DircmpTitle           cterm=bold,underline ctermfg=gray guifg=gray
highlight DircmpMessage         ctermfg=lightgreen    guifg=lightgreen
highlight DircmpAttribute       ctermfg=darkgray      guifg=darkgray

highlight default link DircmpSign1             DircmpSignEqual
highlight default link DircmpSign2             DircmpSignDiffer
highlight default link DircmpSign3             DircmpSignExcess
highlight default link DircmpSign4             DircmpSignConflict

highlight default link DircmpText1             DircmpTextEqual
highlight default link DircmpText2             DircmpTextDiffer
highlight default link DircmpText3             DircmpTextExcess
highlight default link DircmpText4             DircmpTextConflict

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: et ts=4 sts=4 sw=4
