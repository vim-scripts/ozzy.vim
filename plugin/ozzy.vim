" ============================================================================
" File: ozzy.vim
" Description: Open your files from everywhere
" Mantainer: Giacomo Comitti (https://github.com/gcmt)
" Url: https://github.com/gcmt/ozzy.vim
" License: MIT
" Version: 3.0
" Last Changed: 27/03/2013
" ============================================================================

" Init {{{

if exists('g:ozzy_disable')
    let s:disable = g:vand_disable
else
    let s:disable = 0
endif

if s:disable || exists("g:ozzy_loaded") || &cp
    finish
endif

if !has('python')
    echohl WarningMsg | echom "Ozzy requires vim to be compiled with Python 2.6+" | echohl None
    finish
endif

if v:version < 703
    echohl WarningMsg | echom "Ozzy requires vim 7.3+" | echohl None
    finish
endif

python << END
import vim, sys

if sys.version_info[:2] < (2, 6):
    vim.command('let s:unsupported_python = 1')
END

if exists('s:unsupported_python')
    echohl WarningMsg | echom "Ozzy requires vim to be compiled with Python 2.6+" | echohl None
    finish
endif

let g:ozzy_loaded = 1

" }}}


" Initialize settings
let g:ozzy_ignore = get(g:, 'ozzy_ignore', [])
let g:ozzy_track_only = get(g:, 'ozzy_track_only', [])
let g:ozzy_max_entries = get(g:, 'ozzy_max_entries', 15)
let g:ozzy_prompt = get(g:, 'ozzy_prompt', ' ❯ ')


" Create the plugin object
let py_module = fnameescape(globpath(&runtimepath, 'plugin/ozzy.py'))
exe 'pyfile ' . py_module
python ozzy_plugin = Ozzy()


" Commands
command! Ozzy py ozzy_plugin.Open()
command! OzzyReset py ozzy_plugin.Reset()


" Autocommands
augroup ozzy_plugin
    au!
    au BufReadPost,BufNewFile,BufCreate,BufAdd * python ozzy_plugin.update_buffer()
    au VimLeave * python ozzy_plugin.close()
augroup END
