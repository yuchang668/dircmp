let s:diff_path = exepath(get(g:, 'dircmp_diff_path', 'diff'))
if empty(s:diff_path)
    call dircmp#util#echomsg('the diff executable program is not found.')
    finish
endif

let g:dircmp#diff#LACK = 0
let g:dircmp#diff#EQUAL = 1
let g:dircmp#diff#DIFFER = 2
let g:dircmp#diff#EXCESS = 3
let g:dircmp#diff#CONFLICT = 4

let s:PATTERN = [
            \['Files \(.*\) and \(.*\) are identical', g:dircmp#diff#EQUAL],
            \['Files \(.*\) and \(.*\) differ', g:dircmp#diff#DIFFER],
            \['Only in \(.*\): \(.*\)', g:dircmp#diff#EXCESS],
            \['File \(.*\) is a directory while file \(.*\) is a regular file', g:dircmp#diff#CONFLICT],
            \['File \(.*\) is a regular file while file \(.*\) is a directory', g:dircmp#diff#CONFLICT],
            \]

lockvar g:dircmp#diff#LACK g:dircmp#diff#EQUAL g:dircmp#diff#DIFFER g:dircmp#diff#EXCESS g:dircmp#diff#CONFLICT s:PATTERN

function s:parse(basedir, msg, cb) abort
    for [pat, state] in s:PATTERN
        let pair = matchlist(a:msg, pat)[1:2]
        if !empty(pair)
            if state == g:dircmp#diff#EXCESS
                let pair = map(['', ''], {idx,val -> dircmp#util#startswith(pair[0], a:basedir[idx]) ? dircmp#util#pathjoin(pair) : val})
            endif
            for idx in range(len(pair))
                let path = pair[idx]
                if !empty(path)
                    let path = strpart(path, len(a:basedir[idx]))
                    if path[0] == g:dircmp#util#PATHSEP
                        let path = strpart(path, 1)
                    endif
                    call call(a:cb, [idx, path, state])
                endif
            endfor
            return
        endif
    endfor
endfunction

function dircmp#diff#exec(out_cb, exit_cb, fsicase, diffopt, exclude, ...) abort
    if a:0 != 2 || !(filereadable(a:1) || isdirectory(a:1)) || !(filereadable(a:2) || isdirectory(a:2)) | return | endif
    let cmd = [s:diff_path, '-qsr', '--speed-large-files', empty(a:fsicase) ? '--no-ignore-file-name-case' : '--ignore-file-name-case']
    let diffopt = substitute(a:diffopt, '[^iBbwZ]', '', 'g')
    if !empty(diffopt) | call add(cmd, '-' . diffopt) | endif
    if type(a:exclude) == v:t_string && !empty(a:exclude)
        call add(add(cmd, '-X'), a:exclude)
    elseif type(a:exclude) == v:t_list
        for pat in a:exclude
            if type(pat) == v:t_string && !empty(a:exclude)
                call add(add(cmd, '-x'), a:exclude)
            endif
        endfor
    endif
    let basedir = a:000
    call extend(cmd, basedir)
    return dircmp#util#exec(cmd, {_,msg -> s:parse(basedir, msg, a:out_cb)}, 0, a:exit_cb)
endfunction
