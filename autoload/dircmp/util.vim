if !has('job') || !has('channel') | finish | endif

let g:dircmp#util#PATHSEP = (has('win16') || has('win32') || has('win64')) && !(exists('+shellslash') && &shellslash) ? '\' : '/'
lockvar g:dircmp#util#PATHSEP

function dircmp#util#echo(msg) abort
    echohl DircmpMessage | echo a:msg | echohl None
endfunction

function dircmp#util#echomsg(msg) abort
    echohl DircmpMessage | echomsg empty(a:msg) ? '' : 'dircmp: ' . a:msg | echohl None
endfunction

function dircmp#util#strcmp(s1, s2) abort
    return a:s1 ==# a:s2 ? 0 : a:s1 ># a:s2 ? 1 : -1
endfunction

function dircmp#util#stricmp(s1, s2) abort
    return a:s1 ==? a:s2 ? 0 : a:s1 >? a:s2 ? 1 : -1
endfunction

function dircmp#util#startswith(text, str) abort
    return strpart(a:text, 0, len(a:str)) == a:str
endfunction

function dircmp#util#dirname(path) abort
    let dirpath = fnamemodify(a:path, ':h')
    return dirpath == '.' ? '' : dirpath
endfunction

function dircmp#util#pathjoin(seps) abort
    return join(a:seps, g:dircmp#util#PATHSEP)
endfunction

function dircmp#util#glob(expr, ignore) abort
    try
        let saved = &wildignore
        let &wildignore = join(a:ignore, ',')
        return glob(a:expr, 0, 1)
    finally
        let &wildignore = saved
    endtry
endfunction

function dircmp#util#exec(cmd, out_cb, err_cb, exit_cb) abort
    let opts = {'in_io': 'null', 'out_io': 'null', 'err_io': 'null', 'exit_cb': a:exit_cb}
    if type(a:out_cb) == v:t_func
        let opts['out_cb'] = a:out_cb
        let opts['out_io'] = 'pipe'
        let opts['out_mode'] = 'nl'
    endif
    if type(a:err_cb) == v:t_func
        let opts['err_cb'] = a:err_cb
        let opts['err_io'] = 'pipe'
        let opts['err_mode'] = 'nl'
    endif
    return job_start(a:cmd, opts)
endfunction
