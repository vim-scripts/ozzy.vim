" ============================================================================
" File: ozzy.vim
" Description: Open your files from everywhere
" Mantainer: Giacomo Comitti (https://github.com/gcmt)
" Url: https://github.com/gcmt/ozzy.vim
" License: MIT
" Version: 3.3
" Last Changed: 6/24/2013
" ============================================================================

" Init {{{

if  v:version < 703 || !has('python') || exists("g:ozzy_loaded") || &cp
    finish
endif

let g:ozzy_loaded = 1

" }}}


" Initialize settings
let g:ozzy_ignore = get(g:, 'ozzy_ignore', [])
let g:ozzy_track_only = get(g:, 'ozzy_track_only', [])
let g:ozzy_prompt = get(g:, 'ozzy_prompt', '>> ')
let g:ozzy_max_entries = get(g:, 'ozzy_max_entries', 15)
let g:ozzy_default_mode = get(g:, 'ozzy_default_mode', 0)
let g:ozzy_show_file_names = get(g:, 'ozzy_show_file_names', 0)
let g:ozzy_ignore_case = get(g:, 'ozzy_ignore_case', 1)
let g:ozzy_global_mode_flag = get(g:, 'ozzy_global_mode_flag', '')
let g:ozzy_project_mode_flag = get(g:, 'ozzy_project_mode_flag', '')
let g:ozzy_root_markers = get(g:, 'ozzy_root_markers', ['.git', '.svn', '.hg', 'AndroidManifest.xml'])
let g:ozzy_paths_color = get(g:, 'ozzy_paths_color', 'gui=NONE guifg=#777777 cterm=NONE ctermfg=242')
let g:ozzy_paths_color_darkbg = get(g:, 'ozzy_paths_color_darkbg', '')
let g:ozzy_matches_color = get(g:, 'ozzy_matches_color', 'gui=bold guifg=#ff6155 cterm=bold ctermfg=203')
let g:ozzy_matches_color_darkbg = get(g:, 'ozzy_matches_color_darkbg', '')
let g:ozzy_last_dir_color = get(g:, 'ozzy_last_dir_color', 'gui=bold cterm=bold')
let g:ozzy_last_dir_color_darkbg = get(g:, 'ozzy_last_dir_color_darkbg', '')


" Create the plugin object
let py_module = fnameescape(globpath(&runtimepath, 'plugin/ozzy.py'))
exe 'pyfile ' . py_module
python ozzy_plugin = Ozzy()


" Commands
command! Ozzy py ozzy_plugin.Open()
command! OzzyReset py ozzy_plugin.Reset()
command! OzzyToggleMode py ozzy_plugin.ToggleMode()


" Autocommands
augroup ozzy_plugin
    au!
    au BufReadPost,BufNewFile,BufCreate,BufAdd * python ozzy_plugin.update_buffer()
    au VimLeave * python ozzy_plugin.close()
    au Colorscheme * python ozzy_plugin.launcher.setup_colors()
augroup END
