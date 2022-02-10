if !has('timers') | finish | endif

let s:context = {}

let s:verbose = !empty(get(g:, 'dircmp_verbose'))

let s:iswindows = has('win16') || has('win32') || has('win64')

lockvar s:verbose s:iswindows

let s:folder_default = has_key(g:, 'dircmp_folder_default') && type(g:dircmp_folder_default) == v:t_string ? index(['unfold', 'folded'], g:dircmp_folder_default) : -1

function s:context.init(fsicase, exclude, basedir) dict
    let ctx = copy(self)
    let ctx.dirty = 0
    let ctx.running = 0
    let ctx.pending = {}
    let ctx.children = {}
    let ctx.default = s:folder_default >= 0 ? s:folder_default : 1
    let ctx.verbose = s:verbose
    let ctx.fsicase = a:fsicase
    let ctx.exclude = a:exclude
    let ctx.basedir = a:basedir
    let ctx.entries = {}
    let ctx.visible = {}
    let ctx.endpart = {}
    let ctx.exhibit = []
    let ctx._cached = []
    let ctx._excess = []
    let ctx._corked = []
    return ctx
endfunction

function s:context.tokey(path) dict
    return self.fsicase ? tolower(a:path) : a:path
endfunction

function s:context.query(path) dict
    return get(self.entries, self.tokey(a:path), {})
endfunction

function s:context.fsync(path, base) abort dict
    let entry = self.query(a:path)
    if empty(entry) || !has_key(entry.value, a:base) | return {} | endif
    let path = empty(a:path) ? self.basedir[a:base] : dircmp#util#pathjoin([self.basedir[a:base], a:path])
    return extend(entry.value[a:base], {'type': getftype(path), 'time': getftime(path), 'size': getfsize(path), 'perm': getfperm(path)})
endfunction

function s:addpath(path, base, state, level) abort dict
    if empty(a:path) | return self | endif
    let parent = call('s:addpath', [dircmp#util#dirname(a:path), a:base, a:state, a:level], self)
    let key = self.tokey(a:path)
    if !has_key(self.entries, key)
        let self.entries[key] = {'key': key, 'state': a:state, 'level': a:level.value, 'value': {}, 'parent': parent, 'children': {}}
        let parent.children[self.tokey(fnamemodify(a:path, ':t'))] = self.entries[key]
    endif
    let entry = self.entries[key]
    if entry.state != a:state
        let entry.state = g:dircmp#diff#DIFFER
    endif
    if !has_key(entry.value, a:base)
        let entry.value[a:base] = {'base': a:base, 'path': a:path, 'name': fnamemodify(a:path, ':t')}
        call self.fsync(a:path, a:base)
        if !empty(self.running)
            call add(self._corked, entry.value[a:base])
        endif
    endif
    let a:level.value += 1
    return entry
endfunction

function s:context.addpath(path, base, state) abort dict
    let level = {'value': 0}
    return call('s:addpath', [a:path, a:base, a:state, level], self)
endfunction

function s:context.delpath(path, base) abort dict
    let entry = self.query(a:path)
    if empty(entry) | return | endif
    if has_key(entry.value, a:base)
        return remove(entry.value, a:base)
    endif
    call remove(entry.parent.children, self.tokey(fnamemodify(a:path, ':t')))
    for child in values(entry.children)
        call self.delpath(child.key, a:base)
    endfor
    return remove(self.entries, entry.key)
endfunction

function s:globdir(base, path) abort dict
    for path in dircmp#util#glob(dircmp#util#pathjoin([self.basedir[a:base], a:path, '*']), self.exclude)
        let subpath = strpart(path, len(self.basedir[a:base]))
        if subpath[0] == g:dircmp#util#PATHSEP
            let subpath = strpart(subpath, 1)
        endif
        if isdirectory(path)
            call add(self._excess, [a:base, subpath])
        else
            call self.addpath(subpath, a:base, g:dircmp#diff#EXCESS)
        endif
    endfor
endfunction

function s:walkdir(job, timer) abort dict
    if !empty(self._excess)
        return call('s:globdir', remove(self._excess, 0), self)
    elseif job_status(a:job) != 'run'
        return timer_stop(a:timer)
    endif
endfunction

function s:caption(job, timer) abort dict
    if !empty(self._corked)
        let node = remove(self._corked, 0)
        let entry = self.query(node.path)
        if dircmp#pane#visible(self.exhibit, entry)
            if entry.parent is self
                let self.dirty = 1
            else
                for cached in self._cached
                    if entry.parent is cached && empty(get(cached, 'folded', self.running))
                        let self.dirty = 1
                    endif
                endfor
            endif
        endif
        return call('dircmp#pane#title', [self.windows[node.base], dircmp#util#pathjoin([self.basedir[node.base], node.path])], self)
    elseif job_status(a:job) != 'run'
        let self.running = 0
        let self.default = s:folder_default >= 0 ? s:folder_default : 0
        call timer_stop(a:timer)
        for base in range(len(self.windows))
            call call('dircmp#pane#title', [self.windows[base], self.basedir[base]], self)
        endfor
        call dircmp#util#echomsg('['. strftime('%Y/%m/%d %T') . '] finished.')
        return call('dircmp#pane#render', ['expanding view, which may take some minutes.'], self)
    endif
endfunction

function s:render(job, timer) abort dict
    if empty(self.dirty) | return | endif
    let self.dirty = 0
    if empty(self._corked) && job_status(a:job) != 'run'
        return timer_stop(a:timer)
    endif
    return call('dircmp#pane#render', ['scanning changes, which may take some minutes.'], self)
endfunction

function s:diff_output(base, path, state) abort dict
    let entry = self.addpath(a:path, a:base, a:state)
    if (a:state == g:dircmp#diff#EXCESS || a:state == g:dircmp#diff#CONFLICT) && entry.value[a:base].type == 'dir'
        call add(self._excess, [a:base, a:path])
    endif
endfunction

function s:diff_exit(job, status) abort dict
    return call('dircmp#pane#render', [], self)
endfunction

function s:diff_exec(fsicase, diffopt, exclude, ...) abort dict
    let job = dircmp#diff#exec(funcref('s:diff_output', [], self), funcref('s:diff_exit', [], self), a:fsicase, a:diffopt, a:exclude, a:1, a:2)
    if job_status(job) != 'run' | return -1 | endif
    let self.running = 1
    call timer_start(9, funcref('s:walkdir', [job], self), {'repeat': -1})
    call timer_start(29, funcref('s:caption', [job], self), {'repeat': -1})
    call timer_start(30000, funcref('s:render', [job], self), {'repeat': -1})
    call dircmp#util#echomsg('['. strftime('%Y/%m/%d %T') . '] start to indexing ...')
endfunction

function s:dircmp_exec(...) abort
    let exclude = filter(type(a:3) == v:t_list ? copy(a:3) : type(a:3) == v:t_string && filereadable(a:3) ? readfile(a:3) : [], {
                \_,val -> type(val) == v:t_string && !empty(val)})
    let ctx = s:context.init(a:1, exclude, a:000[3:4])
    let tabnr = call('dircmp#pane#init', [], ctx)
    if !empty(call('s:diff_exec', a:000, ctx))
        silent execute 'tabclose! ' . tabnr
        return -1
    endif
endfunction

function dircmp#exec(A, B) abort
    let fsicase = exists('g:dircmp_fs_icase') ? g:dircmp_fs_icase : s:iswindows
    let exclude = ''
    if exists('g:dircmp_exclude')
        let exclude = type('g:dircmp_exclude') == v:t_string && g:dircmp_exclude == '&' ? split(&wildignore, ',') : g:dircmp_exclude
    endif
    let diffopt = []
    for opt in split(&diffopt, ',')
        if opt == 'icase'     | call add(diffopt, 'i') | endif
        if opt == 'iblank'    | call add(diffopt, 'B') | endif
        if opt == 'iwhite'    | call add(diffopt, 'b') | endif
        if opt == 'iwhiteall' | call add(diffopt, 'w') | endif
        if opt == 'iwhiteeol' | call add(diffopt, 'Z') | endif
    endfor
    return s:dircmp_exec(fsicase, join(diffopt, ''), exclude, a:A, a:B)
endfunction
