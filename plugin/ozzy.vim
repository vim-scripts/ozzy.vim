" ============================================================================
" File: ozzy.vim
" Description: Open almost any file from anywhere  
" Mantainer: Giacomo Comitti (https://github.com/gcmt)
" Url: https://github.com/gcmt/ozzy.vim
" License: MIT
" Version: 0.1
" Last Changed: 6 Oct 2012
" ============================================================================


" init ------------------------------------------ {{{

if exists("g:loaded_ozzy") || &cp || !has('python')
    finish
endif
let g:loaded_ozzy = 1

" }}}

" set default options --------------------------- {{{

if !exists('g:ozzy_mode')
    let g:ozzy_mode = 'most_frequent'
endif

if !exists('g:ozzy_freeze')
    let g:ozzy_freeze = 0
endif      

if !exists('g:ozzy_ignore_ext')
    let g:ozzy_ignore_ext = 1
endif

if !exists('g:ozzy_ignore')
    let g:ozzy_ignore = []
endif

if !exists('g:ozzy_keep')
    let g:ozzy_keep = 0
endif    
 
if !exists('g:ozzy_enable_shortcuts')
    let g:ozzy_enable_shortcuts = 1
endif    

if !exists('g:ozzy_most_frequent_flag')
    let g:ozzy_most_frequent_flag = 'F'
endif 

if !exists('g:ozzy_most_recent_flag')
    let g:ozzy_most_recent_flag = 'R'
endif  

if !exists('g:ozzy_freeze_off_flag')
    let g:ozzy_freeze_off_flag = ''
endif 

if !exists('g:ozzy_freeze_on_flag')
    let g:ozzy_freeze_on_flag = 'freeze'
endif   

" }}}


python << END

# ozzy init {{{             
# ============================================================================

# -*- coding: utf-8 -*-

import vim
import os
import shelve
import datetime
from datetime import datetime as dt
from collections import namedtuple
from operator import attrgetter


PLUGIN_PATH = vim.eval("expand('<sfile>:h')")
DB_NAME = 'ozzy'
PATH = os.path.join(PLUGIN_PATH, DB_NAME)

Record = namedtuple('Record', 'path frequency last_access')
buffers = []

try:
    db = shelve.open(PATH, writeback=True)
except:
    vim.command('finish')

# }}}

# vim options to python {{{
# ===================================================================

# g:ozzy_freeze to ozzy_is_frozen
if vim.eval('g:ozzy_freeze') == '1':
    ozzy_is_frozen = True
else:
    ozzy_is_frozen = False

# g:ozzy_ignore_ext to ignore_ext
if vim.eval('g:ozzy_ignore_ext') == '1':
    ignore_ext = True      
else:
    ignore_ext = False  

# g:keep_only_days to keep_only
try:
    val = int(vim.eval('g:ozzy_keep'))
    if val >= 0:
        ozzy_keep = val 
    else: 
        ozzy_keep = 0
except ValueError:
    vim.command("echoerr 'check if the variable"
                "''g:ozzy_keep'' has been setted properly'")
    vim.command('finish') 

# g:ozzy_mode to ozzy_mode
if vim.eval('g:ozzy_mode') in ['most_frequent', 'most_recent']: 
    ozzy_mode = vim.eval('g:ozzy_mode')  
else:
    vim.command("echoerr 'check if the variable"
                "''g:ozzy_mode'' has been setted properly'")
    vim.command('finish')
    
# g:ozzy_ignore to ignore
ignore = vim.eval('g:ozzy_ignore')   

# }}}

# inspector definition and creation {{{
class Inspector(object):
    
    def __init__(self):
        self.name = 'ozzy_inspector'
        self.order_by = ('frequency' if ozzy_mode == 'most_frequent' 
                         else 'last_access')  
        self.reverse_order = True 
        self.show_help = False
        self.short_path = True
        self.cursor = [1, 0]
        self.last_path_under_cursor = ''
        self.mapper = {} # line to record mapper

inspector = Inspector()
# }}}

# main function
# ============================================================================

# _update_curr_buffer {{{
def _update_buffer(bufname=None):
    """Update the attributes of the current opened file in the database.

    This function is called every time a new buffer is read (BufReadPost vim
    event). If Ozzy is 'frozen' the function does nothing. Otherwise, if the
    file name does not match any of the patterns in the ignore list, the
    frequency and the last access attributes of the corrispondent record in the
    database are updated. If no matching record is found, it is created.
    """

    if ozzy_is_frozen:
        return

    if bufname is None:
        bufname = vim.current.buffer.name
    _cond = not _match_ignore_patterns(bufname, ignore) 
    if _cond and bufname not in buffers:
        if bufname in db:
            db[bufname] = Record(bufname, db[bufname].frequency + 1, dt.now())
        else: 
            db[bufname] = Record(bufname, 1, dt.now())
        
        # add to 'listed buffers' global register
        buffers.append(bufname)
# }}}

# helper functions
# ============================================================================

# _find_matches {{{
def _find_matches(target, records):
    matches = []
    for r in records:
        cond1 = r.path.endswith(target) 
        path_no_ext = os.path.splitext(r.path)[0]
        cond2 = ignore_ext and path_no_ext.endswith(target)
        if cond1 or cond2:
            matches.append(r)
    return matches        
# }}}

# _most_frequent_path {{{
def _most_frequent_path(records):
    if records:
        return max(records, key=attrgetter('frequency'))
# }}}

# _most_recent_path {{{
def _most_recent_path(records):
    if records:
        return max(records, key=attrgetter('last_access'))   
# }}}

# _remove_from_db_if {{{
def _remove_from_db_if(func, getter):
    nremoved = 0
    for record in db.values():
        if func(getter(record)):
            del db[record.path]
            nremoved += 1
    return nremoved    
# }}}

# _match_ignore_patters {{{
def _match_ignore_patterns(target, patterns):
    for patt in patterns:
        if patt.startswith('*.'):
            if target.endswith(patt[1:]):
                return True
        elif patt.endswith('.*'):
            fname = os.path.split(target)[1]
            if fname.startswith(patt[:-2]):
                return True
        elif patt.endswith('/'):
            if patt in target:
                return True
        elif os.path.split(target)[1] == patt:
            return True
    return False
# }}}                

# _print_current_mode {{{
def _print_current_mode():
    if ozzy_mode == 'most_frequent':
        echom('Ozzy: most_frequent on')
    else:
        echom('Ozzy: most_recent on')
# }}}

# _print_current_freeze_status {{{
def _print_current_freeze_status():
    if ozzy_is_frozen:
        echom('Ozzy: freeze on')
    else:
        echom('Ozzy: freeze off')
# }}}

# _print_current_extension_status {{{
def _print_current_extension_status():
    if ignore_ext:
        echom('Ozzy: ignore extensions')
    else:
        echom('Ozzy: consider extensions')
# }}}

# _inspector_exists {{{
def _inspector_exists():
    if vim.eval("buflisted('%s')" % inspector.name) == '0':
        return False
    else:
        return True
# }}}

# _save_inspector_cursor_pos {{{
def _save_inspector_cursor_pos():
    global inspector
    line, col = vim.current.window.cursor
    inspector.cursor = [line, col]
    if line in inspector.mapper:
        inspector.last_path_under_cursor = inspector.mapper[line]
# }}}

# _update_inspector {{{        
def _update_inspector(func):
    def wrapper(*args, **kwargs):
        _save_inspector_cursor_pos()
        func()
        OzzyInspect()       
        _insert_line_indicator()

    return wrapper   
# }}}  

# _update_inspector_if_exists RETHINK?? {{{
def _update_inspector_if_exists(func):
    def wrapper(*args, **kwargs):
        _save_inspector_cursor_pos()
        func()
        if not _inspector_exists():
            return
        OzzyInspect()       
        _insert_line_indicator()

    return wrapper
# }}}

# echom {{{
def echom(msg):
    vim.command('echom "%s"' % msg)
# }}}

# interface functions
# ============================================================================

# OzzyOpen {{{
def OzzyOpen(target):
    """Open the given file according to the current mode"""

    matches = _find_matches(target, db.values())
    
    if ozzy_mode == 'most_frequent':
        record = _most_frequent_path(matches)
    else:
        record = _most_recent_path(matches)

    if record:
        vim.command("e %s" % record.path)
    else:
        echom('Ozzy: No file found')   
# }}}

# OzzyRemove {{{
def OzzyRemove(target):
    """To remove records from the database according to the given pattern."""

    t = target.strip()
    if t.startswith('*.'):
        nremoved = _remove_from_db_if(
            lambda path: path.endswith(t[1:]),
            attrgetter('path'))
    elif t.endswith('.*'):
        nremoved = _remove_from_db_if(
            lambda path: os.path.split(path)[1].startswith(target[:-2]),
            attrgetter('path')) 
    elif t.endswith('/'):
        nremoved = _remove_from_db_if(
            lambda path: t in path,
            attrgetter('path')) 
    else:
        nremoved = _remove_from_db_if(
            lambda path: os.path.split(path)[1] == t,
            attrgetter('path'))
    
    echom("Ozzy: %d files removed" % nremoved)
# }}}

# OzzyKeepLast {{{
def OzzyKeepLast(args):  
    """Remove all records older than the given weeks/days/hours/minutes."""

    try:
        n, what = args.strip().split()
        n = int(n)
    except ValueError:
        echom('Ozzy: bad argument!')
        return
        
    if what in ['weeks', 'week', 'w']:
        delta = {'weeks': n}
    elif what in ['days', 'day', 'd']:
        delta = {'days': n}
    elif what in ['hours', 'hour', 'h']:
        delta = {'hours': n}
    elif what in ['minutes', 'minute', 'min', 'mins', 'm']:
        delta = {'minutes': n}
    else:
        echom('Ozzy: bad argument!')
        return

    nremoved = _remove_from_db_if(
                lambda time: 
                    (dt.now() - time) > datetime.timedelta(**delta),
                attrgetter('last_access'))

    echom('Ozzy: %d files removed' % nremoved)
# }}}

# OzzyReset {{{
def OzzyReset():
    """To clear the entire database."""

    answer = vim.eval("input('Are you sure? (yN): ')")
    vim.command('redraw') # to clear the command line
    if answer in ['y', 'Y', 'yes', 'Yes']:
        db.clear() 
        echom('Ozzy: database successfully cleared!')
    else:
        echom('Ozzy: database untouched!')
# }}}

# OzzyInspect {{{
def OzzyInspect(order_by=None, reverse_order=None, show_help=None,
                short_path=None):
    """Open the database inpsector."""

    global inspector

    # update the inspector environment if something has changed
    if order_by is not None:
        inspector.order_by = order_by
    if reverse_order is not None:
        inspector.reverse_order = reverse_order
    if show_help is not None:
        inspector.show_help = show_help
    if short_path is not None:
        inspector.short_path = short_path

    vim.command("e %s" % inspector.name)
    vim.command("setlocal buftype=nofile")
    vim.command("setlocal bufhidden=wipe")
    vim.command("setlocal encoding=utf-8")
    vim.command("setlocal noswapfile")
    vim.command("setlocal noundofile")
    vim.command("setlocal nobackup")
    vim.command("setlocal nowrap")
    vim.command("setlocal modifiable")
    _render_inspector()
    vim.command("setlocal nomodifiable")

    _map_keys()
# }}}

# ToggleMode {{{
@_update_inspector_if_exists
def ToggleMode():
    global ozzy_mode
    # update inspector attribute to reflect this change when its opened
    global inspector
    if ozzy_mode == 'most_frequent':
        ozzy_mode = 'most_recent'    
        inspector.order_by = 'last_access' 
    else:
        ozzy_mode = 'most_frequent'
        inspector.order_by = 'frequency' 
    _print_current_mode()
# }}}

# ToggleFreeze {{{            
@_update_inspector_if_exists
def ToggleFreeze():
    global ozzy_is_frozen
    ozzy_is_frozen = not ozzy_is_frozen
    _print_current_freeze_status()
# }}}

# ToggleExtension {{{              
@_update_inspector_if_exists
def ToggleExtension():
    global ignore_ext
    ignore_ext = not ignore_ext
    _print_current_extension_status()
# }}}

# ozzy inspector
# ============================================================================

# _render_inspector {{{             
def _render_inspector():

    global inspector
    inspector.mapper.clear()

    records = sorted(db.values(), key=attrgetter(inspector.order_by),
                     reverse=inspector.reverse_order) 

    b = vim.current.buffer

    freeze = 'on' if ozzy_is_frozen else 'off' 
    ext = 'ignore' if ignore_ext else 'consider'

    b.append(' >> Ozzy Inspector')
    b.append('')
    b.append(' Ozzy status [mode: %s] [freeze: %s] [extensions: %s]'
             % (ozzy_mode, freeze, ext))
    b.append('')

    if inspector.show_help:
        _help = [
            ' - help',
            '   ----------------------------------',
            '   q : quit inspector',
            '   ? : toggle help',
            '   p : toggle between absolute and relative to home paths',
            '   f : order records by frequency (default)',
            '   a : order records by date and time',
            '   r : reverse the current order',
            '   o : open the file on the current line',
            '   b : open in background the file on the current line',
            '   + : increase the frequency of the file on the current line',
            '   - : decrease the frequency of the file on the current line',
            '   t : touch the file on the current line (set its ''last access attribute'' to now)',
            '   dd : remove from the list the record under the cursor (or an entire selection)',
            '        For additional power see OzzyRm, OzzyKeepLast and OzzyReset commands'
        ]

        for l in _help:
            b.append(l)
    else:
        b.append(' ▪ type ? for help')

    b.append('')
    b.append(" last access          freq   file path")
    b.append(" -------------------  -----  -------------------")

    # print records

    for r in records:
        last_access = r.last_access.strftime('%Y-%m-%d %H:%M:%S')
        if inspector.short_path:
            path = r.path.replace(os.path.expanduser('~'), '~')
        else:
            path = r.path
        b.append(" %s %6s  %s" % (last_access, r.frequency, path))
        inspector.mapper[len(b)] = r.path

    # adjust cursor position

    if not records: 
        b.append('')
        inspector.cursor = [len(b), 1]

    elif inspector.cursor[0] not in inspector.mapper:
        inspector.cursor = [min(inspector.mapper), 1]
    else:
        # prevent the cursor to be moved to a non-exitent position
        if inspector.cursor[0] > len(b):
            inspector.cursor = [len(b), 0]
        else:
            line = _get_line_last_path()
            if line:
                inspector.cursor[0] = line

    vim.current.window.cursor = inspector.cursor

    # draw line indicator 

    _insert_line_indicator()
# }}}

# _get_line_last_path {{{
def _get_line_last_path():
    for line, path in inspector.mapper.items():
        if path == inspector.last_path_under_cursor:
            return line 
# }}}

# _map_keys {{{
def _map_keys():
    #disable = ['q', 'f', 'a', 'd', '+', 'o', 'b', '-', 't', 'r', 'p', '?']
    mappings = (
        'q :bd', 

        'f :python OzzyInspect(order_by="frequency")',

        'a :python OzzyInspect(order_by="last_access")',

        'o :python _open_record_curr_line()',

        'b :python _open_record_curr_line_bg()',

        'dd :python _delete_selected_records()',

        '+ :python _increment_freq_record_curr_line()',

        '- :python _decrement_freq_record_curr_line()',

        't :python _touch_record_curr_line()',

        ('r :python OzzyInspect(reverse_order=%r)' 
         % (not inspector.reverse_order)),
        
        ('p :python OzzyInspect(short_path=%r)'
         % (not inspector.short_path)),

        ('? :python OzzyInspect(show_help=%r)'
         % (not inspector.show_help)),
    )

    for m in mappings:
        vim.command('nnoremap <buffer> <silent> ' + m + '<CR>')

    vim.command('vnoremap <buffer> <silent> '
                'dd :python _delete_selected_records()<CR>')
# }}}

# _insert_line_indicator FIX!! {{{
def _insert_line_indicator():
    bufname = vim.current.buffer.name
    cond1 = bufname and bufname.endswith(inspector.name)
    cond2 = bufname and len(vim.current.buffer) > 1
    if cond1 and cond2:
        vim.command("setlocal modifiable")
        curr_linenr, _ = vim.current.window.cursor
        b = vim.current.buffer
        indicator = '▸'

        for linenr in inspector.mapper:
            if linenr > 1 and linenr == curr_linenr: 
                if indicator not in b[linenr - 1]: 
                    b[linenr - 1] = indicator + b[linenr - 1][1:] 
            else:
                b[linenr - 1] = b[linenr - 1].replace(indicator, ' ')   
        
        vim.command("setlocal nomodifiable")
# }}}

# _delete_selected_records {{{ 
@_update_inspector 
def _delete_selected_records(): 
    start = vim.current.buffer.mark('<')
    end = vim.current.buffer.mark('>')
    if start is None: # there is no range
        path = _get_path_on_line(vim.current.window.cursor[0])
        if path:
            del db[path]
    else:
        for line in range(start[0], end[0]+1):
            path = _get_path_on_line(line)
            if path:
                del db[path]
        vim.command('delmarks <>')
# }}}

# _touch_record_curr_line {{{
@_update_inspector
def _touch_record_curr_line():
    """Set the last access date to now"""
    path = _get_path_on_line(vim.current.window.cursor[0])
    if path:            
        db[path] = _clone_record(db[path], last_access=dt.now())
# }}}

# _increment_freq_record_curr_line {{{             
@_update_inspector
def _increment_freq_record_curr_line():
    path = _get_path_on_line(vim.current.window.cursor[0])
    if path:            
        db[path] = _clone_record(db[path], frequency=db[path].frequency+1)
# }}}

# _decrement_freq_record_curr_line {{{  
@_update_inspector
def _decrement_freq_record_curr_line():
    path = _get_path_on_line(vim.current.window.cursor[0])
    if path:            
        if db[path].frequency > 1:
            db[path] = _clone_record(db[path], frequency=db[path].frequency-1)
# }}}

# _open_record_curr_line {{{  
def _open_record_curr_line():
    path = _get_path_on_line(vim.current.window.cursor[0])
    vim.command('e %s' % path)
# }}}    
 
# _open_record_curr_line_bg {{{ 
@_update_inspector
def _open_record_curr_line_bg():
    path = _get_path_on_line(vim.current.window.cursor[0])
    vim.command('bad %s' % path)
    _update_buffer(path)
# }}}   

# _get_path_on_line {{{               
def _get_path_on_line(line):
    if inspector.mapper:
        return inspector.mapper.get(line, None) 
# }}}

# _clone_record {{{
def _clone_record(rec, last_access=None, frequency=None):
    new_last_access = last_access if last_access else rec.last_access
    new_frequency = frequency if frequency else rec.frequency
    return Record(rec.path, new_frequency, new_last_access) 
# }}}                    

# environment consistency functions
# ============================================================================

# _remove_unlisted_buffers {{{
def _remove_unlisted_buffers(): 
    listed_buf = [b.name for b in _listed_buffers()]
    for b in buffers:  # buffers is global
        if b not in listed_buf:
            buffers.remove(b) 
# }}}

# _init_inspector_when_closed {{{
def _init_inspector_when_closed():
    if not _inspector_exists():
        inspector.__init__()
# }}}

# _listed_buffers {{{
def _listed_buffers():
    return [bufname for bnr, bufname in enumerate(vim.buffers)
            if int(vim.eval('buflisted(%d)' % (bnr + 1)))]
# }}}

# _remove_deleted_files_from_db {{{
def _db_maintenance():
    for r in db.values():
        cond1 = not os.path.exists(r.path)
        cond2 = (ozzy_keep and (dt.now() - r.last_access > 
                                datetime.timedelta(days=ozzy_keep)))
        if cond1 or cond2:
            del db[r.path]            
# }}}

# _db_maintenance_and_closing FIX?? {{{            
def _db_maintenance_and_closing():
    _db_maintenance()
    db.close()
# }}}

# debug utils
# ============================================================================

# print_mapper {{{
def print_mapper():
    print inspector.mapper
# }}}

END


" functions to get ozzy status {{{
" useful to display the Ozzy status on the status bar

function! OzzyModeFlag()
python << END
vim.command('let s:curr_mode = "%s"' % ozzy_mode)
END
    if s:curr_mode == 'most_frequent'
        return g:ozzy_most_frequent_flag
    else
        return g:ozzy_most_recent_flag
    endif
endfunction

function! OzzyFreezeFlag()
python << END
vim.command('let s:curr_freeze_status = %s' % (1 if ozzy_is_frozen else 0))
END
    if s:curr_freeze_status
        return g:ozzy_freeze_on_flag
    else
        return g:ozzy_freeze_off_flag
    endif
endfunction   

" }}}

" autocommands {{{   
" ============================================================================  

augroup ozzy_plugin
    au!
    au CursorMoved * python _insert_line_indicator()
    au BufEnter * python _remove_unlisted_buffers()
    au BufEnter * python _init_inspector_when_closed()
    au BufReadPost * python _update_buffer()
    au VimLeave * python _db_maintenance_and_closing()
augroup END 

" }}}

" commands {{{
" ========================================================= 

command! OzzyInspect python OzzyInspect()
command! -nargs=1 Ozzy python OzzyOpen(<q-args>)

command! OzzyReset python OzzyReset()
command! -nargs=1 OzzyRemove python OzzyRemove(<q-args>)
command! -nargs=+ OzzyKeepLast python OzzyKeepLast(<q-args>)

command! OzzyToggleMode python ToggleMode()
command! OzzyToggleFreeze python ToggleFreeze()
command! OzzyToggleExtension python ToggleExtension()

if g:ozzy_enable_shortcuts
    command! Oi python OzzyInspect()
    command! -nargs=1 O python OzzyOpen(<q-args>)
    command! -nargs=1 Orm python OzzyRemove(<q-args>)
    command! -nargs=+ Okeep python OzzyKeepLast(<q-args>)
endif       

" }}}
