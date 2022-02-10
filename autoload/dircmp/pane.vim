let s:ignevents = ['VimEnter', 'BufEnter', 'WinEnter', 'VimLeave', 'BufLeave', 'WinLeave']

let s:diffdict = {'equal': g:dircmp#diff#EQUAL, 'differ': g:dircmp#diff#DIFFER, 'excess': g:dircmp#diff#EXCESS, 'conflict': g:dircmp#diff#CONFLICT}

let s:folder = ['▸', '▾']

lockvar s:ignevents s:diffdict s:folder

function s:fileicon(name)
    return ' '
endfunction

function s:complete(A, L, P)
    return keys(s:diffdict)
endfunction

function s:pane_init() abort
    setlocal filetype=dircmp
    setlocal buftype=nofile
    setlocal bufhidden=unload
    setlocal signcolumn=yes
    setlocal foldcolumn=0
    setlocal foldmethod=manual
    setlocal nolist
    setlocal nowrap
    setlocal nospell
    setlocal nonumber
    setlocal noswapfile
    setlocal scrollbind
    setlocal cursorbind
    setlocal cursorline
    setlocal nomodified
    setlocal nobuflisted
    setlocal nomodifiable
    setlocal nofoldenable
    setlocal conceallevel=3
    setlocal concealcursor=nvic
    setlocal norelativenumber
    setlocal statusline=%<%f

    syntax match DircmpTitle /\%1l.*/
    syntax match DircmpAttribute /[0-9 -:]\+$/

    for key in [g:dircmp#diff#EQUAL, g:dircmp#diff#DIFFER, g:dircmp#diff#EXCESS, g:dircmp#diff#CONFLICT]
        silent execute 'syntax region DircmpText' . key . ' matchgroup=Ignore start="<' . key . '" end=">" keepend concealends'
        silent execute 'sign define sign' . key . ' text=\  texthl=DircmpSign' . key
    endfor

    autocmd Dircmp VimResized <buffer> call s:pane_resize()
    autocmd Dircmp CursorHold <buffer> call s:pane_notice()

    noremap <buffer> <silent> <special> <C-H>       :silent execute 'DircmpHide ' . substitute(getline('.'), '^[^<]*<[1234]\(.*\)>[^>]*$', '\1', '')<CR>
    noremap <buffer> <silent> <special> <Tab>       :DircmpJumpTo<CR>
    noremap <buffer> <silent> <special> <S-Tab>     :DircmpToggle<CR>
    noremap <buffer> <silent> <special> <Return>    :DircmpSwitch<CR>

    command -buffer -nargs=* DircmpHide             call s:pane_hide(<f-args>)
    command -buffer -nargs=* DircmpUnhide           call s:pane_unhide(<f-args>)
    command -buffer -nargs=0 DircmpToggle           call s:pane_toggle()
    command -buffer -nargs=0 -range DircmpSwitch    <line1>,<line2>call s:pane_switch()
    command -buffer -nargs=? -complete=customlist,s:complete DircmpJumpTo  call s:pane_jumpto(<f-args>)
    command -buffer -nargs=* -complete=customlist,s:complete DircmpDisplay call s:pane_display(<f-args>)
endfunction

function s:pane_call(winid, func, ...) abort
    let result = 0
    let currid = win_getid()
    if win_gotoid(a:winid)
        setlocal modifiable
        let currpos = getpos('.')
        let result = call(a:func, a:000)
        call setpos('.', currpos)
        setlocal nomodifiable
    endif
    call win_gotoid(a:winid)
    return result
endfunction

function s:pane_setline(nr, row, text) abort
    call setbufvar(a:nr, '&modifiable', 1)
    call setbufline(a:nr, a:row, a:text)
    call setbufvar(a:nr, '&modifiable', 0)
endfunction

function s:pane_addline(nr, row, text) abort
    call setbufvar(a:nr, '&modifiable', 1)
    call appendbufline(a:nr, a:row, a:text)
    call setbufvar(a:nr, '&modifiable', 0)
endfunction

function s:pane_delline(nr, row) abort
    call setbufvar(a:nr, '&modifiable', 1)
    call deletebufline(a:nr, a:row)
    call setbufvar(a:nr, '&modifiable', 0)
endfunction

function s:pane_draw(oldview, newview, windows, verbose, default) abort
    let wwin = map(copy(a:windows), {_,wid -> winwidth(wid)})
    let bufs = map(copy(a:windows), {_,wid -> winbufnr(wid)})
    let nums = range(len(bufs))
    for entry in a:oldview
        let entry.dirty = !empty(get(entry, 'dirty')) - 2
    endfor
    for entry in a:newview
        let entry.dirty = get(entry, 'dirty') + 2
    endfor
    for idx in range(len(a:oldview) - 1, 0, -1)
        let entry = a:oldview[idx]
        if entry.dirty < 0
            let row = idx + 2
            for base in nums
                call sign_unplace('dircmp', {'buffer': bufs[base], 'id': entry._sign[base]})
                call s:pane_delline(bufs[base], row)
            endfor
            call remove(entry, '_sign')
            call remove(entry, 'dirty')
            call remove(a:oldview, idx)
        endif
    endfor
    for idx in range(len(a:newview))
        let entry = a:newview[idx]
        let dirty = remove(entry, 'dirty')
        if !dirty | continue | endif
        let row = idx + 2
        let indent = repeat('  ', entry.level)
        let entry._sign = {}
        for base in nums
            let text = ''
            if has_key(entry.value, base)
                let node = entry.value[base]
                let text = indent . (node.type == 'dir' ? s:folder[empty(get(entry, 'folded', a:default))] : s:fileicon(node.name)) . ' ' .
                            \ '<' . entry.state . node.name . '>' .
                            \ (node.type == 'dir' ? g:dircmp#util#PATHSEP : stridx(node.perm, 'x') >= 0 ? '*' : '')
                if !empty(a:verbose)
                    let padded = ''
                    let vacant = wwin[base] - strdisplaywidth(text) - 1
                    for attr in [node.size, strftime('%Y-%m-%d %T', node.time)]
                        if len(padded) + len(attr) > vacant | break | endif
                        let padded .= ' ' . attr
                    endfor
                    let text .= repeat(' ', vacant - len(padded) + 2) . padded
                endif
            endif
            if dirty == 1
                call s:pane_setline(bufs[base], row, text)
            else
                call s:pane_addline(bufs[base], row - 1, text)
            endif
            let entry._sign[base] = sign_place(0, 'dircmp', 'sign' . entry.state, bufs[base], {'lnum': row})
        endfor
    endfor
endfunction

function s:pane_toggle() abort
    if !has_key(t:, 'dircmp') | return | endif
    let t:dircmp.verbose = !t:dircmp.verbose
    return s:pane_refresh('force')
endfunction

function s:pane_refresh(...) abort
    if !has_key(t:, 'dircmp') | return | endif
    if !empty(get(a:000, 0))
        for cached in t:dircmp._cached
            let cached.dirty = 1
        endfor
    endif
    return call('s:view_update', [], t:dircmp)
endfunction

function s:pane_display(...) abort
    if !has_key(t:, 'dircmp') | return | endif
    let t:dircmp.exhibit = filter(map(copy(a:000), {_,val -> get(s:diffdict, val, g:dircmp#diff#LACK)}), {_,val -> val != g:dircmp#diff#LACK})
    return call('dircmp#pane#render', ['redrawing view, which may take some minutes.'], t:dircmp)
endfunction

function s:pane_hide(...) abort
    if !has_key(t:, 'dircmp') | return | endif
    let Fn = t:dircmp.fsicase ? {str,pat -> str =~? pat} : {str,pat -> str =~# pat}
    let patterns = map(copy(a:000), {_,val -> glob2regpat(val)})
    for entry in values(t:dircmp.entries)
        for pattern in patterns
            if Fn(entry.key, pattern)
                let entry.hidden = 1
                break
            endif
        endfor
    endfor
    return call('dircmp#pane#render', ['redrawing view, which may take some minutes.'], t:dircmp)
endfunction

function s:pane_unhide(...) abort
    if !has_key(t:, 'dircmp') | return | endif
    let entries = sort(filter(values(t:dircmp.entries), {_,entry -> !empty(get(entry, 'hidden'))}),
                \ t:dircmp.fsicase ? {a,b -> dircmp#util#stricmp(a.key, b.key)} : {a,b -> dircmp#util#strcmp(a.key, b.key)})
    let nums = len(entries)
    if !nums | return | endif
    while !a:0
        let choose = inputlist(insert(map(copy(entries), {idx,entry -> (idx + 1) . '. ' . entry.key}), 'Hidden entries:'))
        if 0 < choose && choose <= len(entries) | call remove(remove(entries, choose - 1), 'hidden') | else | break | endif
    endwhile
    let hit = 0
    if a:0 && !empty(entries)
        let Fn = t:dircmp.fsicase ? {str,pat -> str =~? pat} : {str,pat -> str =~# pat}
        let patterns = map(copy(a:000), {_,val -> glob2regpat(val)})
        for entry in entries
            for pattern in patterns
                if Fn(entry.key, pattern)
                    let hit = 1
                    call remove(entry, 'hidden')
                    break
                endif
            endfor
        endfor
    endif
    if !hit && nums == len(entries) | return | endif
    return call('dircmp#pane#render', ['redrawing view, which may take some minutes.'], t:dircmp)
endfunction

function s:pane_resize()
    if !has_key(t:, 'dircmp') || empty(t:dircmp.verbose) | return | endif
    return s:pane_refresh('force')
endfunction

function s:pane_notice() abort
    if !has_key(t:, 'dircmp') | return | endif
    let idx = line('.') - 2
    let base = index(t:dircmp.windows, win_getid())
    if idx < 0 || base < 0 | return | endif
    let entry = get(t:dircmp._cached, idx, {})
    if empty(entry) || empty(get(entry.value, base)) | return | endif
    let node = entry.value[base]
    return dircmp#util#echo(printf('%s: %s%s %s %d', dircmp#util#pathjoin([t:dircmp.basedir[base], node.path]), node.type == 'dir' ? 'd' : '-', node.perm, strftime('%Y-%m-%d %T', node.time), node.size))
endfunction

function s:pane_switch() range abort
    if !has_key(t:, 'dircmp') | return | endif
    let base = index(t:dircmp.windows, win_getid())
    for row in range(a:lastline, a:firstline, -1)
        let idx = row - 2
        let entry = get(t:dircmp._cached, idx, {})
        if idx < 0 || empty(entry) | continue | endif
        if len(entry.value) == 2 && entry.value[0].type == 'file' && entry.value[1].type == 'file'
            call call('s:view_open', map(values(entry.value), {base,node -> dircmp#util#pathjoin([t:dircmp.basedir[base], node.path])}), t:dircmp)
        elseif !empty(filter(copy(entry.value), {_,node -> node.type == 'dir'}))
            let entry.dirty = 1
            let entry.folded = !get(entry, 'folded', t:dircmp.default)
        elseif has_key(entry.value, base) && entry.value[base].type == 'file'
            call call('s:view_open', [dircmp#util#pathjoin([t:dircmp.basedir[base], entry.value[base].path])], t:dircmp)
        endif
    endfor
    return s:pane_refresh()
endfunction

function s:pane_jumpto(...) abort
    if !has_key(t:, 'dircmp') | return | endif
    let idx = line('.') - 2
    let base = index(t:dircmp.windows, win_getid())
    if idx < 0 || base < 0 | return | endif
    let entry = get(t:dircmp._cached, idx, {})
    if empty(entry) | return | endif
    let state = a:0 ? get(s:diffdict, a:1, entry.state) : entry.state
    let current = get(entry, 'visible')
    let current = !empty(current) ? current : t:dircmp.visible
    while current isnot entry
        if current.state == state | break | endif
        let current = get(current, 'visible')
        let current = !empty(current) ? current : t:dircmp.visible
    endwhile
    if current is entry | return | endif
    let parent = get(current, 'parent')
    let entry = parent
    while !empty(entry) && entry isnot t:dircmp
        let entry.dirty = 1
        let entry.folded = 0
        let entry = get(entry, 'parent')
    endwhile
    if entry != parent | call s:pane_refresh() | endif
    return sign_jump(current._sign[base], 'dircmp', winbufnr(t:dircmp.windows[base]))
endfunction

function s:pane_focus() abort
    if !has_key(t:, 'dircmp') | return | endif
    let t:dircmp.eventignore = &eventignore
    let &eventignore = join(s:ignevents, ',')
    if !empty(get(t:dircmp.pending, 'title'))
        for base in range(len(t:dircmp.windows))
            call call('dircmp#pane#title', [t:dircmp.windows[base], t:dircmp.basedir[base]], t:dircmp)
        endfor
    endif
    if !empty(get(t:dircmp.pending, 'render'))
        call call('dircmp#pane#render', [], t:dircmp)
    endif
endfunction

augroup Dircmp
    autocmd TabEnter * call s:pane_focus()
    autocmd TabLeave * if has_key(get(t:, 'dircmp', {}), 'eventignore') | let &eventignore = t:dircmp.eventignore | endif
augroup END

function s:view_open(path, ...) abort dict
    let wid = win_getid()
    silent execute 'noautocmd $tabedit ' . (a:0 ? '+vertical\ rightbelow\ diffsplit\ ' . fnameescape(a:1) . ' ' : '') . fnameescape(a:path)
    let bufs = tabpagebuflist(tabpagenr('$'))
    for base in range(len(bufs))
        silent execute 'autocmd! BufUnload <buffer=' . bufs[base] . '> if win_gotoid(' . self.windows[base] . ') | tabclose | endif'
    endfor
    return win_gotoid(wid)
endfunction

function s:view_visit(...) abort dict
    let current = self
    let current.visible = {}
    for [_, child] in sort(items(self.children), a:1)
        if empty(call(a:2, [child], self)) | continue | endif
        let current.visible = child
        let current = call('s:view_visit', a:000, child)
        let self.endpart = current
    endfor
    return current
endfunction

function s:view_update() abort dict
    let entries = []
    let current = get(self, 'visible')
    while !empty(current)
        call add(entries, current)
        if has_key(current, 'endpart')
            let current.dirty = get(current, 'dirty', !self.running)
            if !empty(get(current, 'folded', self.default))
                let current = current.endpart
            endif
        endif
        let current = get(current, 'visible')
    endwhile
    call s:pane_draw(self._cached, entries, self.windows, self.verbose, self.default)
    let self._cached = entries
endfunction

function dircmp#pane#init() abort dict
    let eventsaved = &eventignore
    let &eventignore = join(s:ignevents, ',')
    silent execute 'noautocmd $tabedit +vsplit\ ' . fnameescape(self.basedir[0]) . ' ' . fnameescape(self.basedir[1])
    let result = gettabinfo(tabpagenr('$'))[0]
    for wid in result.windows
        call s:pane_call(wid, 's:pane_init')
    endfor
    let self.windows = result.windows
    let self.eventignore = eventsaved
    let t:dircmp = self
    lockvar 1 t:dircmp
    return result.tabnr
endfunction

function dircmp#pane#title(winid, title) abort dict
    if gettabvar(tabpagenr(), 'dircmp') isnot self
        let self.pending['title'] = 1
        return -1
    endif
    call s:pane_setline(winbufnr(a:winid), 1, a:title . repeat(' ', winwidth(a:winid) - strdisplaywidth(a:title) + 1))
    let self.pending['title'] = 0
endfunction

function dircmp#pane#render(...) abort dict
    if gettabvar(tabpagenr(), 'dircmp') isnot self
        let self.pending['render'] = 1
        return -1
    endif
    call dircmp#util#echo(get(a:000, 0, 'rendering ...'))
    call call('s:view_visit', [
                \ self.fsicase ? {a,b -> dircmp#util#stricmp(a[0], b[0])} : {a,b -> dircmp#util#strcmp(a[0], b[0])},
                \ funcref('dircmp#pane#visible', [self.exhibit]),
                \ ], self)
    call call('s:view_update', [], self)
    call dircmp#util#echo(get(a:000, 1, ''))
    let self.pending['render'] = 0
endfunction

function dircmp#pane#visible(exhibit, entry) abort
    return empty(get(a:entry, 'hidden')) && (empty(a:exhibit) || index(a:exhibit, a:entry.state) >= 0)
endfunction
