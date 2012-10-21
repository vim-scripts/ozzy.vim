" ============================================================================
" File: ozzy.vim
" Description: Quick files launcher  
" Mantainer: Giacomo Comitti (https://github.com/gcmt)
" Url: https://github.com/gcmt/ozzy.vim
" License: MIT
" Version: 0.5
" Last Changed: 21 Oct 2012
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

if !exists('g:ozzy_max_num_files_to_open')
    let g:ozzy_max_num_files_to_open = 0
endif      

if !exists('g:ozzy_ignore_case')
    let g:ozzy_ignore_case = 0
endif         

if !exists('g:ozzy_most_frequent_flag')
    let g:ozzy_most_frequent_flag = 'F'
endif 

if !exists('g:ozzy_most_recent_flag')
    let g:ozzy_most_recent_flag = 'T'
endif  

if !exists('g:ozzy_context_flag')
    let g:ozzy_context_flag = 'C'
endif       

if !exists('g:ozzy_freeze_off_flag')
    let g:ozzy_freeze_off_flag = 'off'
endif 

if !exists('g:ozzy_freeze_on_flag')
    let g:ozzy_freeze_on_flag = 'on'
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
from operator import attrgetter, itemgetter
from heapq import nlargest


# set the path for the database location
PLUGIN_PATH = vim.eval("expand('<sfile>:h')")
DB_NAME = 'ozzy'
PATH = os.path.join(PLUGIN_PATH, DB_NAME)

# database record
Record = namedtuple('Record', 'path frequency last_access')

# current opened buffers
buffers = [] 
                                                     
# modes
MODES = ['most_frequent', 'most_recent', 'context']

try:
    db = shelve.open(PATH, writeback=True)
except:
    db = {}
    msg = 'ozzy log: cannot create the database into ' + PATH
    vim.command('echom "%s"' % msg)
# }}}

# settings management {{{      
# ===================================================================

# set setting value
def let(name, value=None):
    prefix = 'g:ozzy_'

    if isinstance(value, str):
        val = "'%s'" % value 
    elif isinstance(value, bool):
        val = "%d" % (1 if value else 0) 
    else:
        val = value

    vim.command("let %s = %s" % (prefix + name, val))

# get setting value
def setting(name, fmt=None):
    prefix = 'g:ozzy_'

    raw_val = vim.eval(prefix + name)
    if fmt:
        if fmt is bool:
            val = True if raw_val == '1' else False
        else:
            try:
                val = fmt(raw_val)
            except ValueError:
                return None
        return val
    else:
        return raw_val

# }}}

# check settings validity {{{                    
# ===================================================================

if any((setting('mode') not in MODES,
       setting('max_num_files_to_open', fmt=int) < 0,
       setting('keep', fmt=int) < 0,
    )):
    msg = ("ozzy log: some setting has not been setted properly. "
           "Something may not work as expected.")
    vim.command('echom "%s"' % msg)

# }}}

# inspector definition and creation {{{                
class Inspector(object):
    """Inspector definition.

    Note about self.mapper:
    When a user want to perform an action in the inspector buffer, he moves the
    cursor on the line where the records of its interest is positionated and
    the he perform the action action (pressing a specific key). The mapper
    serves the purpose of mapping lines of the nuffer with records displayed on
    them, so that the action is performed on the right record.
    """
    
    def __init__(self):
        self.name = 'ozzy_inspector'
        self.order_by = ('frequency' if setting('mode') == 'most_frequent' 
                         else 'last_access')  
        self.reverse_order = True 
        self.show_help = False
        self.short_paths = True
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

    This function is called whenever a buffer is read (on BufReadPost vim 
    event).
    """
    if bufname is None:
        bufname = vim.current.buffer.name  

    if (setting('freeze', fmt=bool) 
        or os.path.split(bufname)[1] == inspector.name):
        return

    _cond = not _match_patterns(bufname, setting('ignore')) 
    if _cond and bufname not in buffers:
        if bufname in db:
            db[bufname] = Record(bufname, db[bufname].frequency + 1, dt.now())
        else: 
            db[bufname] = Record(bufname, 1, dt.now())

        buffers.append(bufname) # 'buffers' is global
# }}}

# helper functions
# ============================================================================

# _update_inspector {{{               
def _update_inspector(func):
    def wrapper(*args, **kwargs):
        _save_inspector_cursor_pos()
        func(*args, **kwargs)
        if not _inspector_is_current_buffer():
            return
        OzzyInspect()       
        _insert_line_indicator()

    return wrapper   
# }}}  

# _sync_db {{{
def _sync_db(func):
    def wrapper(*args, **kwargs):
        func(*args, **kwargs)
        db.sync()
    return wrapper
# }}}

# _find_fname_match {{{                     
def _find_fname_match(target):
    matches = []
    for r in db.values():
        fname = os.path.split(r.path)[1]
        fname_no_ext = os.path.splitext(fname)[0]

        if setting('ignore_case', fmt=int):
            fname = fname.lower()
            fname_no_ext = fname_no_ext.lower()

        cond1 = target == fname 
        cond2 = setting('ignore_ext', fmt=bool) and fname_no_ext == target
        if cond1 or cond2:
            matches.append(r)

    return matches        
# }}}

 # _find_path_match {{{                    
def _find_path_match(target):
    matches = []
    for r in db.values():
 
        if setting('ignore_case', fmt=int):
            path = r.path.lower()
        else:
            path = r.path

        path_no_ext = os.path.splitext(path)[0]

        cond1 = path.endswith(target)
        cond2 = setting('ignore_ext', fmt=bool) and path_no_ext.endswith(target)
        if cond1 or cond2:
            matches.append(r)

    return matches        
# }}}        

# _find_path_endswith {{{
def _find_path_endswith(target):
    return [record for record in db.values()
            if os.path.split(record.path)[0].endswith(target[:-1])] 
# }}} 

# _find_path_contains {{{
def _find_path_contains(target):
    target = target.strip('/')
    return [path for path, _, _ in records 
            if '/' + target in os.path.split(path)[0]]
# }}}               

# _find_matches_distance {{{             
def _find_matches_distance(target): 
    """Returns all matches and their relative distance to cwd"""

    matches = _find_fname_match(target.strip())        

    cwd = vim.eval('getcwd()')
    r = []     

    for match in matches:
        if match.path.startswith(cwd):            
            p = match.path[len(cwd):]  # remove cwd from path
            # get the number of directories between cwd and the the file
            r.append((match, len(p.split('/')[1:-1])))
        else:
            cwd_lst = cwd.strip('/').split('/')
            path_lst = match.path.strip('/').split('/')[:-1]
            for f1, f2 in zip(cwd_lst, path_lst):
                if f1 == f2:
                    cwd_lst.remove(f1)
                    path_lst.remove(f1)

            r.append((match, len(cwd_lst) + len(path_lst)))

    return r
# }}}

# _remove_from_db_if {{{                
@_sync_db
def _remove_from_db_if(func, getter):
    nremoved = 0
    for record in db.values():
        if func(getter(record)):
            del db[record.path]
            nremoved += 1
    return nremoved    
# }}}

# _match_patterns {{{                 
def _match_patterns(target, patterns):
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
    echom('Ozzy: mode %s' % setting('mode'))
# }}}

# _print_current_freeze_status {{{                
def _print_current_freeze_status():
    if setting('freeze', fmt=bool):
        echom('Ozzy: freeze on')
    else:
        echom('Ozzy: freeze off')
# }}}

# _print_current_extension_status {{{             
def _print_current_extension_status():
    if setting('ignore_ext', fmt=bool):
        echom('Ozzy: ignore extensions')
    else:
        echom('Ozzy: consider extensions')
# }}}

# _save_inspector_cursor_pos {{{             
def _save_inspector_cursor_pos():
    global inspector
    line, col = vim.current.window.cursor
    inspector.cursor = [line, col]
    if line in inspector.mapper:
        inspector.last_path_under_cursor = inspector.mapper[line]
# }}}

# _inspector_is_current_buffer {{{                
def _inspector_is_current_buffer():
    bufname = vim.current.buffer.name
    if bufname and bufname.endswith(inspector.name):
        return True
    else:
        return False
# }}}

# _escape_spaces {{{
def _escape_spaces(s):
    return s.replace(' ', '\ ')    
# }}}

# echom {{{                     
def echom(msg):
    vim.command('echom "%s"' % msg)
# }}}

# interface functions
# ============================================================================

# OzzyOpen {{{                       
def OzzyOpen(target):
    """Open the given file according to the current mode.
    
       If a directory name is given, all files in that direcotory are opened.
    """

    target = target.strip()

    attr = ('frequency' if setting('mode') in ['most_frequent', 'context'] 
            else 'last_access')

    if target.endswith('/'): 
        # open all files in the given directory

        matches = _find_path_endswith(target)
        
        n = setting('max_num_files_to_open', fmt=int)
        if n > 0:
            paths = [r.path for r in nlargest(n, matches, key=attrgetter(attr))]
        else:
            paths =  [r.path for r in matches]

        if matches:
            vim.command("args " + ' '.join(_escape_spaces(p) for p in paths))
            echom('Ozzy: %d files opened' % len(paths))
        else:
            echom('Ozzy: No file found')

    else: 
        # open a single file

        if '/' in target:
            matches = _find_path_match(target)

        elif setting('mode') == 'context':
            # sort matches by distance: the closests first
            _matches = sorted(_find_matches_distance(target), 
                              key=lambda t: t[1])
            if _matches:
                minim = _matches[0][1]  # get the distance of the fist match
                # sort closests matches by frequency: most accessed first
                match = max([match for match, n in _matches if n == minim],
                            key=attrgetter(attr))

                vim.command("e " + _escape_spaces(match.path))
            else:
                echom('Ozzy: No file found') 
            return

        else:
            matches = _find_fname_match(target)  

        if matches:
            record = max(matches, key=attrgetter(attr))
            vim.command("e %s" % _escape_spaces(record.path))
        else:
            echom('Ozzy: No file found')   
# }}}

# OzzyRemove {{{               
@_update_inspector
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
@_update_inspector
def OzzyKeepLast(args):  
    """Remove all records according to the given period of time.
    
    The period of time might be expressed in minutest, hours, days or weeks.
    Examples: 30 minutes, 3 hours, 1 day, 2 weeks
    If a there is a file in the database that has not been opened in the last n 
    minutes/hours/days/weeks is removed.
    """

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
@_sync_db
@_update_inspector
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
                short_paths=None):
    """Open the database inpsector."""

    global inspector

    # update the inspector environment if something has changed
    if order_by is not None:
        inspector.order_by = order_by
    if reverse_order is not None:
        inspector.reverse_order = reverse_order
    if show_help is not None:
        inspector.show_help = show_help
    if short_paths is not None:
        inspector.short_paths = short_paths

    vim.command("e %s" % inspector.name)

    if vim.eval('&cursorline') != '0':
        vim.command("setlocal cursorline")

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

# OzzyAddDirectory {{{  
@_sync_db
def AddDirectory(args):

    def get_opt(option, arglist, expect_arg=True):
        try:
            if expect_arg:
                return arglist[arglist.index(option) + 1]
            else:
                if arglist.index(option):
                    return True
        except (IndexError, ValueError):
            pass

    # return true if cur_root is not a directory contained into an hidden
    # directory
    def into_hidden_dir(cur_root, topdir):
        s = cur_root.replace(topdir, '')
        return any([t.startswith('.') for t in s.split('/')]) 
    

    arglist = args.split()

    topdir = arglist[0]
    if topdir == '.':
        topdir = vim.eval('getcwd()')

    # extract options from the argument list

    a_opt = get_opt('-a', arglist)
    if a_opt:
        add_list = a_opt.strip(',').split(',')
    else:
        add_list = []

    i_opt = get_opt('-i', arglist)
    if i_opt:
        ignore_list = i_opt.strip(',').split(',')
    else:
        ignore_list = [] 

    add_hidden_dirs = get_opt('-h', arglist, expect_arg=False)
        
    # find all files

    paths = []
    for root , dirs, files in os.walk(topdir):

        if (add_hidden_dirs
            or not into_hidden_dir(root, topdir)):

            for f in files:
                path = os.path.join(root, f)

                if (not _match_patterns(path, setting('ignore')) 
                    and path not in db):

                    if ((not ignore_list
                         or not _match_patterns(path, ignore_list))
                        and
                        (not add_list
                         or _match_patterns(path, add_list))):

                        paths.append(path)

    msg = ("input('I''m going to add %d files, are you sure? (yN): ')" 
           % len(paths))
    answer = vim.eval(msg)
    vim.command('redraw') # to clear the command line
    if answer in ['y', 'Y', 'yes', 'Yes']:
        for p in paths:
            db[p] = Record(p, 1, dt.now())  
        echom('Ozzy: %d files successfully added!' % len(paths))
    else:
        echom('Ozzy: no files added!') 
# }}}

# ToggleMode {{{
@_update_inspector
def ToggleMode():
    # update inspector attribute to reflect this change when its opened
    global inspector
    curr_index = MODES.index(setting('mode'))
    if curr_index == len(MODES) - 1:
        next_mode = MODES[0]
    else:
        next_mode = MODES[curr_index + 1]
    let('mode', next_mode)
    inspector.order_by = ('frequency' if setting('mode') == 'most_frequent' 
                          else 'last_access')  
    _print_current_mode()
# }}}

# ToggleFreeze {{{             
@_update_inspector
def ToggleFreeze():
    let('freeze', value=not setting('freeze', fmt=bool))
    _print_current_freeze_status()
# }}}

# ToggleExtension {{{                
@_update_inspector
def ToggleExtension():
    let('ignore_ext', value=not setting('ignore_ext', fmt=bool))
    _print_current_extension_status()
# }}}

# ozzy inspector
# ============================================================================

# _render_inspector {{{                
def _render_inspector():
    """Render the Inspector content."""

    global inspector
    inspector.mapper.clear()

    records = sorted(db.values(), key=attrgetter(inspector.order_by),
                     reverse=inspector.reverse_order) 

    b = vim.current.buffer

    freeze = 'on' if setting('freeze', fmt=bool) else 'off' 
    ext = 'ignore' if setting('ignore_ext', fmt=bool) else 'consider'

    b.append(' >> Ozzy Inspector')
    b.append('')
    b.append(' Ozzy status [mode: %s] [freeze: %s] [extensions: %s]'
             % (setting('mode'), freeze, ext))
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
        if inspector.short_paths:
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
    """To map the keys neede to perform actions in the Inspector."""

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
        
        ('p :python OzzyInspect(short_paths=%r)'
         % (not inspector.short_paths)),

        ('? :python OzzyInspect(show_help=%r)'
         % (not inspector.show_help)),
    )

    for m in mappings:
        vim.command('nnoremap <buffer> <silent> ' + m + '<CR>')

    vim.command('vnoremap <buffer> <silent> '
                'dd :python _delete_selected_records()<CR>')
# }}}

# _insert_line_indicator {{{
def _insert_line_indicator():
    """To insert a little arrow on the line where the cursor is positionated.

    This function is called only inside the Inspector.
    """
    
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
@_sync_db
@_update_inspector 
def _delete_selected_records(): 
    """To delete the selected records from the database.

    This function automatically detect if a selection has been made by the
    user and if so all the selected records are deleted.
    This function is active only when the inspector is opened.
    """
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
@_sync_db
@_update_inspector
def _touch_record_curr_line():
    """Set the last access time of the file on the current line to now.
    
    This function is called only inside the Inspector.
    """

    path = _get_path_on_line(vim.current.window.cursor[0])
    if path:            
        db[path] = _clone_record(db[path], last_access=dt.now())
# }}}

# _increment_freq_record_curr_line {{{             
@_sync_db
@_update_inspector
def _increment_freq_record_curr_line():
    """Increment the frequency attribute of the file on the current line.
    
    This function is called only inside the Inspector.
    """

    path = _get_path_on_line(vim.current.window.cursor[0])
    if path:            
        db[path] = _clone_record(db[path], frequency=db[path].frequency+1)
# }}}

# _decrement_freq_record_curr_line {{{  
@_sync_db
@_update_inspector
def _decrement_freq_record_curr_line():
    """Decrement the frequency attribute of the file on the current line.
    
    This function is called only inside the Inspector.
    """

    path = _get_path_on_line(vim.current.window.cursor[0])
    if path:            
        if db[path].frequency > 1:
            db[path] = _clone_record(db[path], frequency=db[path].frequency-1)
# }}}

# _open_record_curr_line {{{  
def _open_record_curr_line():
    """To open the file on the current line.

    This function is called only inside the Inspector.
    """

    path = _get_path_on_line(vim.current.window.cursor[0])
    if path:
        vim.command('e %s' % _escape_spaces(path))
# }}}    
 
# _open_record_curr_line_bg {{{ 
@_update_inspector
def _open_record_curr_line_bg():
    """To open in backgroung the file on the current line.

    This function is called only inside the Inspector.
    """                 
    path = _get_path_on_line(vim.current.window.cursor[0])
    if path:
        vim.command('bad %s' % _escape_spaces(path))
        _update_buffer(path)
# }}}   

# _get_path_on_line {{{               
def _get_path_on_line(line):
    """To get the right path on the current line. 

    See Inspector definition for more informations
    """
    if inspector.mapper:
        return inspector.mapper.get(line, None) 
# }}}

# _clone_record {{{
def _clone_record(rec, last_access=None, frequency=None):
    """To clone a database record."""

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

# _listed_buffers {{{
def _listed_buffers():
    return [bufname for bnr, bufname in enumerate(vim.buffers)
            if int(vim.eval('buflisted(%d)' % (bnr + 1)))]
# }}}

# _db_maintenance {{{             
def _db_maintenance():
    """Remove deleted files or files not recently opened (see g:ozzy_keep)"""
       
    for r in db.values():
        ozzy_keep = setting('keep', fmt=int)
        cond1 = not os.path.exists(r.path)  # remove non exitent files
        cond2 = (ozzy_keep > 0 and (dt.now() - r.last_access > 
                                datetime.timedelta(days=ozzy_keep)))
        if cond1 or cond2:
            del db[r.path]            
# }}}

# _db_maintenance_and_close {{{             
def _db_maintenance_and_close():
    _db_maintenance()
    db.close()
# }}}

END

" Cmdline_completion {{{          
function! Cmdline_completion(seed, cmdline, curpos)
python << END
seed = vim.eval('a:seed')

if setting('ignore_case', fmt=int):
    matches = [r for r in db.values() 
               if os.path.split(r.path)[1].lower().startswith(seed)]  
else:
    matches = [r for r in db.values() 
               if os.path.split(r.path)[1].startswith(seed)]  

attr = ('frequency' if setting('mode') in ['most_frequent', 'context'] 
        else 'last_access')   
completions = [os.path.split(r.path)[1] for r in
                sorted(matches, key=attrgetter(attr), reverse=True)]

vim.command('let s:completions = %r' % list(set(completions)))
END
    return s:completions
endfunction
" }}}

" functions to get ozzy status {{{
" useful to display the Ozzy status on the status bar

function! OzzyModeFlag()
    if g:ozzy_mode == 'most_frequent'
        return g:ozzy_most_frequent_flag
    elseif g:ozzy_mode == 'most_recent'
        return g:ozzy_most_recent_flag
    else
        return g:ozzy_context_flag
    endif
endfunction

function! OzzyFreezeFlag()
    if g:ozzy_freeze
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
    au BufNewFile,BufReadPost * python _update_buffer()
    au VimLeave * python _db_maintenance_and_close()
augroup END 

" }}}

" commands {{{
" ========================================================= 

command! OzzyInspect python OzzyInspect()
command! -nargs=1 -complete=customlist,Cmdline_completion Ozzy python OzzyOpen(<q-args>)
command! -nargs=+ OzzyAddDirectory python AddDirectory(<q-args>)

command! -nargs=1 -complete=customlist,Cmdline_completion OzzyRemove python OzzyRemove(<q-args>)
command! -nargs=+ OzzyKeepLast python OzzyKeepLast(<q-args>)
command! OzzyReset python OzzyReset()

command! OzzyToggleMode python ToggleMode()
command! OzzyToggleFreeze python ToggleFreeze()
command! OzzyToggleExtension python ToggleExtension()

if g:ozzy_enable_shortcuts
    command! Oi python OzzyInspect()
    command! -nargs=+ OAdd python AddDirectory(<q-args>)
    command! -nargs=1 -complete=customlist,Cmdline_completion O python OzzyOpen(<q-args>)
    command! -nargs=1 -complete=customlist,Cmdline_completion Orm python OzzyRemove(<q-args>)
    command! -nargs=+ Okeep python OzzyKeepLast(<q-args>)
endif       

" }}}
