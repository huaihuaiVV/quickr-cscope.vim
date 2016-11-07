" quick-cscope.vim:   For superfast Cscope results navigation using quickfix window
" Maintainer:         Ronak Gandhi <https://github.com/ronakg>
" Version:            1.0
" Website:            https://github.com/ronakg/quickr-cscope.vim

" Setup {{
if exists("g:quickr_cscope_loaded") || !has("cscope") || !has("quickfix")
    finish
endif
let g:quickr_cscope_loaded = 1
" }}

" s:debug_echo {{
function! s:debug_echo(str)
    if g:quickr_cscope_debug_mode
        echom a:str
    endif
endfunction
" }}

" Options {{
if !exists("g:quickr_cscope_debug_mode")
    let g:quickr_cscope_debug_mode = 0
endif

if !exists("g:quickr_cscope_keymaps")
    let g:quickr_cscope_keymaps = 1
endif

if !exists("g:quickr_cscope_autoload_db")
    let g:quickr_cscope_autoload_db = 1
endif

if !exists("g:quickr_cscope_use_qf_g")
    let g:quickr_cscope_use_qf_g = 0
endif

if !exists("g:quickr_cscope_use_ctrlp_qf")
    let g:quickr_cscope_use_ctrlp_qf = 0
endif

if !exists("g:quickr_cscope_prompt_length")
    let g:quickr_cscope_prompt_length = 3
endif

"==
" windowdir
"  Gets the directory for the file in the current window
"  Or the current working dir if there isn't one for the window.
"  Use tr to allow that other OS paths, too
function s:windowdir()
  if winbufnr(0) == -1
    let unislash = getcwd()
  else 
    let unislash = fnamemodify(bufname(winbufnr(0)), ':p:h')
  endif
    return tr(unislash, '\', '/')
endfunc
"
"==
" Find_in_parent
" find the file argument and returns the path to it.
" Starting with the current working dir, it walks up the parent folders
" until it finds the file, or it hits the stop dir.
" If it doesn't find it, it returns "Nothing"
function s:Find_in_parent(fln,flsrt,flstp)
  let here = a:flsrt
  while ( strlen( here) > 0 )
    if filereadable( here . "/" . a:fln )
      return here
    endif
    let fr = match(here, "/[^/]*$")
    if fr == -1
      break
    endif
    let here = strpart(here, 0, fr)
    if here == a:flstp
      break
    endif
  endwhile
  return "Nothing"
endfunc
" Unload_csdb
"  drop cscope connections.
function s:Unload_csdb()
  if exists("b:csdbpath")
    if cscope_connection(3, "out", b:csdbpath)
      let save_csvb = &csverb
      set nocsverb
      exe "cs kill " . b:csdbpath
      set csverb
      let &csverb = save_csvb
    endif
  endif
endfunc
"
"==
" Cycle_csdb
"  cycle the loaded cscope db.
function s:Cycle_csdb()
    if exists("b:csdbpath")
      if cscope_connection(3, "out", b:csdbpath)
        return
        "it is already loaded. don't try to reload it.
      endif
    endif
    let newcsdbpath = s:Find_in_parent("cscope.out",s:windowdir(),$HOME)
"    echo "Found cscope.out at: " . newcsdbpath
"    echo "Windowdir: " . s:windowdir()
    if newcsdbpath != "Nothing"
      let b:csdbpath = newcsdbpath
      if !cscope_connection(3, "out", b:csdbpath)
        let save_csvb = &csverb
        set nocsverb
        exe "cs add " . b:csdbpath . "/cscope.out " . b:csdbpath
        set csverb
        let &csverb = save_csvb
      endif
      "
    else " No cscope database, undo things. (someone rm-ed it or somesuch)
      call s:Unload_csdb()
    endif
endfunc

augroup autoload_cscope
 au!
 au BufEnter * call <SID>Cycle_csdb()
 " au BufEnter *.cc      call <SID>Cycle_csdb() | call <SID>Cycle_macros_menus()
 au BufUnload * call <SID>Unload_csdb()
 " au BufUnload *.cc     call <SID>Unload_csdb() | call <SID>Cycle_macros_menus()
augroup END

" s:quickr_cscope {{
function! s:quickr_cscope(str, query)
    echohl Question

    " Mark this position
    mark Y
    " Close any open quickfix windows
    cclose

    if g:quickr_cscope_prompt_length > 0
        if strlen(a:str) <= g:quickr_cscope_prompt_length
            let l:search_term = input("Enter search term: ", a:str)
        else
            let l:search_term = a:str
        endif
    endif

    call setqflist([])

    let l:cur_file_name=@%
    echon "Searching for: ".l:search_term
    silent! execute "cs find ".a:query." ".l:search_term

    let l:n_results = len(getqflist())
    echon ". Search returned ". l:n_results . " results."
    if l:n_results > 0
        " If the buffer that cscope jumped to is not same as current file, close the buffer
        if l:cur_file_name != @%
            " Go back to where the command was issued
            bd %
            execute "normal! `Y"
            " We just jumped back to where the command was issued from. So delete the previous
            " buffer, which will the the buffer quickfix jumped to
        endif

        " Open quickfix window
        if g:quickr_cscope_use_ctrlp_qf
            CtrlPQuickfix
        else
            botright cwindow
            " Search for the query string for easy navigation using n and N in quickfix
            if a:query != "f"
                execute "normal /".l:search_term."\<CR>"
            endif
        endif

    endif
    delmarks Y
    echohl None
endfunction
" }}

" s:get_visual_selection {{
" http://stackoverflow.com/a/6271254/777247
function! s:get_visual_selection()
  " Why is this not a built-in Vim script function?!
  let [lnum1, col1] = getpos("'<")[1:2]
  let [lnum2, col2] = getpos("'>")[1:2]
  let lines = getline(lnum1, lnum2)
  let lines[-1] = lines[-1][: col2 - (&selection == 'inclusive' ? 1 : 2)]
  let lines[0] = lines[0][col1 - 1:]
  return join(lines, "\n")
endfunction
" }}

" Plug mappings {{
if g:quickr_cscope_use_qf_g
    nnoremap <silent> <plug>(quickr_cscope_global)    :call <SID>quickr_cscope(expand("<cword>"), "g")<CR>
else
    nnoremap <silent> <plug>(quickr_cscope_global)    :cs find g <cword><CR>
endif

nnoremap <silent> <plug>(quickr_cscope_symbols)       :call <SID>quickr_cscope(expand("<cword>"), "s")<CR>
nnoremap <silent> <plug>(quickr_cscope_callers)       :call <SID>quickr_cscope(expand("<cword>"), "c")<CR>
nnoremap <silent> <plug>(quickr_cscope_files)         :call <SID>quickr_cscope(expand("<cfile>:t"), "f")<CR>
nnoremap <silent> <plug>(quickr_cscope_includes)      :call <SID>quickr_cscope(expand("<cfile>:t"), "i")<CR>
nnoremap <silent> <plug>(quickr_cscope_text)          :call <SID>quickr_cscope(expand("<cword>"), "t")<CR>
vnoremap <silent> <plug>(quickr_cscope_text)          :call <SID>quickr_cscope(<SID>get_visual_selection(), "t")<CR>
nnoremap <silent> <plug>(quickr_cscope_functions)     :call <SID>quickr_cscope(expand("<cword>"), "d")<CR>
nnoremap <silent> <plug>(quickr_cscope_egrep)         :call <SID>quickr_cscope(input('Enter egrep pattern: '), "e")<CR>

vnoremap <silent> <plug>(quickr_cscope_symbols)       :call <SID>quickr_cscope(<SID>get_visual_selection(), "s")<CR>
vnoremap <silent> <plug>(quickr_cscope_callers)       :call <SID>quickr_cscope(<SID>get_visual_selection(), "c")<CR>
vnoremap <silent> <plug>(quickr_cscope_files)         :call <SID>quickr_cscope(<SID>get_visual_selection(), "f")<CR>
vnoremap <silent> <plug>(quickr_cscope_includes)      :call <SID>quickr_cscope(<SID>get_visual_selection(), "i")<CR>
vnoremap <silent> <plug>(quickr_cscope_text)          :call <SID>quickr_cscope(<SID>get_visual_selection(), "t")<CR>
vnoremap <silent> <plug>(quickr_cscope_text)          :call <SID>quickr_cscope(<SID>get_visual_selection(), "t")<CR>
vnoremap <silent> <plug>(quickr_cscope_functions)     :call <SID>quickr_cscope(<SID>get_visual_selection(), "d")<CR>
vnoremap <silent> <plug>(quickr_cscope_egrep)         :call <SID>quickr_cscope(<SID>get_visual_selection(), "e")<CR>
" }}

if g:quickr_cscope_keymaps
    nmap <C-\>g <plug>(quickr_cscope_global)
    nmap <C-\>s <plug>(quickr_cscope_symbols)
    nmap <C-\>c <plug>(quickr_cscope_callers)
    nmap <C-\>f <plug>(quickr_cscope_files)
    nmap <C-\>i <plug>(quickr_cscope_includes)
    nmap <C-\>t <plug>(quickr_cscope_text)
    nmap <C-\>d <plug>(quickr_cscope_functions)
    nmap <C-\>e <plug>(quickr_cscope_egrep)

    vmap <C-\>g <plug>(quickr_cscope_global)
    vmap <C-\>s <plug>(quickr_cscope_symbols)
    vmap <C-\>c <plug>(quickr_cscope_callers)
    vmap <C-\>f <plug>(quickr_cscope_files)
    vmap <C-\>i <plug>(quickr_cscope_includes)
    vmap <C-\>t <plug>(quickr_cscope_text)
    vmap <C-\>d <plug>(quickr_cscope_functions)
    vmap <C-\>e <plug>(quickr_cscope_egrep)
endif

" Use quickfix window for cscope results. Clear previous results before the search.
if g:quickr_cscope_use_qf_g
    set cscopequickfix=g-,s-,c-,f-,i-,t-,d-,e-
    if g:quickr_cscope_use_ctrlp_qf == 0
        augroup autoload_cscope_qf
            au!
            autocmd! FileType qf nnoremap <buffer><silent> q <C-w>q
        augroup END
    endif
else
    set cscopequickfix=s-,c-,f-,i-,t-,d-,e-
endif

" Modeline and Notes {{
" vim: set sw=4 ts=4 sts=4 et tw=99 foldmarker={{,}} foldlevel=10 foldlevelstart=10 foldmethod=marker:
" }}
