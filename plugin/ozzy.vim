" ===========================================================================
" File: ozzy.vim
" Description: Quick files launcher  
" Mantainer: Giacomo Comitti (https://github.com/gcmt)
" Url: https://github.com/gcmt/ozzy.vim
" License: MIT
" Version: 0.6.1
" Last Changed: 24 Oct 2012
" ===========================================================================


" init ------------------------------------------ {{{
if exists("g:loaded_ozzy") || &cp || !has('python')
    finish
endif
let g:loaded_ozzy = 1
" }}}

python << END

# imports {{{
import vim
import os
import shelve
import datetime
from datetime import datetime as dt
from collections import namedtuple
from operator import attrgetter
from heapq import nlargest
# }}}

# database record definition
Record = namedtuple('Record', 'path frequency last_access')


# Utils
# ===========================================================================
class Utils(object): # {{{                 

    @staticmethod
    def escape_spaces(s): # {{{                 
        return s.replace(' ', '\ ') 
    # }}}

    @staticmethod
    def echom(msg): # {{{            
        vim.command('echom "%s"' % msg)
    # }}}

    @staticmethod
    def feedback(msg): # {{{            
        Utils.echom('Ozzy: ' + msg)
    # }}}

    @staticmethod
    def listed_buffers(): # {{{                 
        return [b.name for b in vim.buffers
                if b.name and int(vim.eval('buflisted(%r)' % b.name))]
    # }}}

    @staticmethod
    def clone_record(rec, last_access=None, frequency=None): # {{{        
        """To clone a database record."""
        new_last_access = last_access if last_access else rec.last_access
        new_frequency = frequency if frequency else rec.frequency
        return Record(rec.path, new_frequency, new_last_access) 
    # }}}

# settings proxy functions

    @staticmethod
    def let(name, value=None): # {{{       
        prefix = 'g:ozzy_'
        if isinstance(value, str):
            val = "'%s'" % value 
        elif isinstance(value, bool):
            val = "%d" % (1 if value else 0) 
        else:
            val = value
        vim.command("let %s = %s" % (prefix + name, val))
    # }}}

    @staticmethod
    def setting(name, fmt=None): # {{{          
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

# }}}

# Inspector
# ===========================================================================
class Inspector(object): # {{{              
    """Inspector definition.

    Note about self.mapper:
    When a user want to perform an action in the inspector buffer, he moves the
    cursor on the line where the records of its interest is positionated and
    the he perform the action action (pressing a specific key). The mapper
    serves the purpose of mapping lines of the nuffer with records displayed on
    them, so that the action is performed on the right record.
    """
    
    def __init__(self, ozzy): # {{{          
        self.ozzy = ozzy
        self.name = 'ozzy_inspector'
        self.order_by = ('frequency' if Utils.setting('mode') == 'most_frequent' 
                         else 'last_access')  
        self.reverse_order = True 
        self.show_help = False
        self.short_paths = True
        self.cursor = [1, 0]
        self.last_path_under_cursor = ''
        self.mapper = {} # line to record mapper
    # }}}

    def open(self, order_by=None, reverse_order=None, show_help=None, # {{{
             short_paths=None):          
        """To open the inspector."""
        # update the inspector environment if something has changed
        if order_by is not None:
            self.order_by = order_by
        if reverse_order is not None:
            self.reverse_order = reverse_order
        if show_help is not None:
            self.show_help = show_help
        if short_paths is not None:
            self.short_paths = short_paths

        vim.command("e %s" % self.name)
        vim.command("setlocal buftype=nofile")
        vim.command("setlocal bufhidden=wipe")
        vim.command("setlocal encoding=utf-8")
        vim.command("setlocal noswapfile")
        vim.command("setlocal noundofile")
        vim.command("setlocal nobackup")
        vim.command("setlocal nowrap")
        vim.command("setlocal modifiable")
        self.render()
        vim.command("setlocal nomodifiable")
        self.map_keys()
    # }}}

    def render(self): # {{{          
        """Render the Inspector content."""
        self.mapper.clear()
        b = vim.current.buffer
        freeze = 'on' if Utils.setting('freeze', fmt=bool) else 'off' 
        ext = 'ignore' if Utils.setting('ignore_ext', fmt=bool) else 'consider'
        records = sorted(self.ozzy.db.values(), key=attrgetter(self.order_by),
                         reverse=self.reverse_order) 

        b.append(' >> Ozzy Inspector')
        b.append('')
        b.append(' Ozzy status [mode: %s] [freeze: %s] [extensions: %s]'
                 % (Utils.setting('mode'), freeze, ext))
        b.append('')

        if self.show_help:
            help = [
                ' - help',
                '   ----------------------------------',
                '   q : quit inspector',
                '   ? : toggle help',
                '   p : toggle between absolute and relative-to-home paths',
                '   f : order records by frequency',
                '   a : order records by last access date and time',
                '   r : reverse the current order',
                '   o : open the file on the current line',
                '   b : open in background the file on the current line',
                '   + : increase the frequency of the file on the current line',
                '   - : decrease the frequency of the file on the current line',
                '   t : touch the file on the current line (set its ''last access attribute'' to now)',
                '   dd : remove from the list the record under the cursor (or an entire selection)',
                '        For additional power see OzzyRemove, OzzyKeepLast and OzzyReset commands'
            ]

            for l in help:
                b.append(l)
        else:
            b.append(' ▪ type ? for help')

        # print records

        b.append('')
        b.append(" last access          freq   file path")
        b.append(" -------------------  -----  -------------------")

        for r in records:
            last_access = r.last_access.strftime('%Y-%m-%d %H:%M:%S')

            if self.short_paths:
                path = r.path.replace(os.path.expanduser('~'), '~')
            else:
                path = r.path

            b.append(" %s %6s  %s" % (last_access, r.frequency, path))
            self.mapper[len(b)] = r.path

        # adjust cursor position

        if not records: 
            b.append('')
            self.cursor = [len(b), 1]
        elif self.cursor[0] not in self.mapper:
            self.cursor = [min(self.mapper), 1]
        else:
            # prevent the cursor to be moved to a non-exitent position
            if self.cursor[0] > len(b):
                self.cursor = [len(b), 0]
            else:
                line = self.get_line_last_path()
                if line:
                    self.cursor[0] = line

        vim.current.window.cursor = self.cursor

        self.insert_line_indicator()
    # }}}

    def map_keys(self): # {{{            
        """To map the keys neede to perform actions in the Inspector."""
        mappings = (
            'q :bd', 
            'f :python ozzy.insp.open(order_by="frequency")',
            'a :python ozzy.insp.open(order_by="last_access")',
            'o :python ozzy.insp.open_record_curr_line()',
            'b :python ozzy.insp.open_record_curr_line_bg()',
           'dd :python ozzy.insp.delete_selected_records()',
            '+ :python ozzy.insp.increment_freq_record_curr_line()',
            '- :python ozzy.insp.decrement_freq_record_curr_line()',
            't :python ozzy.insp.touch_record_curr_line()',
           ('r :python ozzy.insp.open(reverse_order=%r)' 
             % (not self.reverse_order)),
            ('p :python ozzy.insp.open(short_paths=%r)'
             % (not self.short_paths)),
            ('? :python ozzy.insp.open(show_help=%r)'
             % (not self.show_help)),
        )

        for m in mappings:
            vim.command('nnoremap <buffer> <silent> ' + m + '<CR>')

        vim.command('vnoremap <buffer> <silent> '
                    'dd :python ozzy.insp.delete_selected_records()<CR>')
    # }}}

    def update_rendering(self): # {{{        
        if not self.is_current_buffer():
            return
        self.open()       
        self.insert_line_indicator()
    # }}}   

    def follow_modified_record(self): # {{{           
        line, col = vim.current.window.cursor
        self.cursor = [line, col]
        if line in self.mapper:
            self.last_path_under_cursor = self.mapper[line]
    # }}}

    def is_current_buffer(self): # FIX: not strong enough {{{
        bufname = vim.current.buffer.name
        return bufname and bufname.endswith(self.name)
    # }}}

    def get_line_last_path(self): # {{{       
        for line, path in self.mapper.items():
            if path == self.last_path_under_cursor:
                return line 
    # }}}

    def insert_line_indicator(self): # {{{           
        """To insert a little arrow on the line where the cursor is positionated.
        """
        bufname = vim.current.buffer.name
        cond1 = bufname and bufname.endswith(self.name)
        cond2 = bufname and len(vim.current.buffer) > 1
        if cond1 and cond2:
            vim.command("setlocal modifiable")
            curr_linenr, _ = vim.current.window.cursor
            b = vim.current.buffer
            indicator = '▸'

            for linenr in self.mapper:
                if linenr > 1 and linenr == curr_linenr: 
                    if indicator not in b[linenr - 1]: 
                        b[linenr - 1] = indicator + b[linenr - 1][1:] 
                else:
                    b[linenr - 1] = b[linenr - 1].replace(indicator, ' ')   
            
            vim.command("setlocal nomodifiable")
    # }}}

    def get_path_on_line(self, line): # {{{
        """To get the right path on the current line."""
        if self.mapper:
            return self.mapper.get(line, None) 
    # }}}

    def delete_selected_records(self): # {{{                 
        """To delete the selected records from the database.

        This function automatically detect if a selection has been made by the
        user and if so all the selected records are deleted.
        """
        start = vim.current.buffer.mark('<')
        end = vim.current.buffer.mark('>')
        if start is None: # there is no range
            path = self.get_path_on_line(vim.current.window.cursor[0])
            if path:
                del self.ozzy.db[path]
        else:
            for line in range(start[0], end[0]+1):
                path = self.get_path_on_line(line)
                if path:
                    del self.ozzy.db[path]
            vim.command('delmarks <>')

        self.ozzy.db.sync()
        self.update_rendering()
    # }}}
    
    def touch_record_curr_line(self): # {{{          
        """Set the last access time of the file on the current line to now."""
        path = self.get_path_on_line(vim.current.window.cursor[0])
        if path:            
            self.ozzy.db[path] = Utils.clone_record(self.ozzy.db[path], 
                                                    last_access=dt.now())

        self.follow_modified_record()
        self.ozzy.db.sync()
        self.update_rendering()
    # }}}

    def increment_freq_record_curr_line(self): # {{{           
        """Increment the frequency attribute of the file on the current line.
        """
        path = self.get_path_on_line(vim.current.window.cursor[0])
        if path:            
            self.ozzy.db[path] = Utils.clone_record(self.ozzy.db[path], 
                frequency=self.ozzy.db[path].frequency+1)

        self.follow_modified_record()
        self.ozzy.db.sync()
        self.update_rendering()
    # }}}

    def decrement_freq_record_curr_line(self): # {{{
        """Decrement the frequency attribute of the file on the current line.
        """
        path = self.get_path_on_line(vim.current.window.cursor[0])
        if path:            
            if self.ozzy.db[path].frequency > 1:
                self.ozzy.db[path] = Utils.clone_record(self.ozzy.db[path], 
                    frequency=self.ozzy.db[path].frequency-1)

        self.follow_modified_record()
        self.ozzy.db.sync()
        self.update_rendering()
    # }}}

    def open_record_curr_line(self): # {{{
        """To open the file on the current line."""
        path = self.get_path_on_line(vim.current.window.cursor[0])
        if path:
            vim.command('e %s' % Utils.escape_spaces(path))
    # }}}    
    
    def open_record_curr_line_bg(self): # {{{

        """To open in backgroung the file on the current line."""                 
        path = self.get_path_on_line(vim.current.window.cursor[0])
        if path:
            vim.command('bad %s' % Utils.escape_spaces(path))
            self.ozzy.update_buffer(path)

        self.follow_modified_record()
        self.ozzy.db.sync()
        self.update_rendering()
    # }}}

# }}}

# Ozzy
# ===========================================================================
class Ozzy(object): # {{{             
    """Main ozzy class."""

    def __init__(self): # {{{          
        # set the path for the database location
        self.PLUGIN_PATH = vim.eval("expand('<sfile>:h')")
        self.DB_NAME = 'ozzy'
        self.PATH = os.path.join(self.PLUGIN_PATH, self.DB_NAME)

        # current opened buffers
        self.buffers = [] 
                                                            
        # modes
        self.MODES = ['most_frequent', 'most_recent', 'context']

        try:
            self.db = shelve.open(self.PATH, writeback=True)
        except:
            self.db = {}
            msg = 'ozzy log: cannot create the database into ' + self.PATH
            vim.command('echom "%s"' % msg)

        self.init_settings()
        self.check_user_settings()

        self.insp = Inspector(self)

    # }}}

    def init_settings(self): # {{{             
        settings = {
            'mode' : 'most_frequent',
            'freeze' : 0,
            'ignore_ext' : 1,
            'ignore' : [],
            'keep' : 0,
            'enable_shortcuts' : 1,
            'max_num_files_to_open' : 0,
            'open_files_recursively' : 1,
            'ignore_case' : 0,
            'most_frequent_flag' : 'F',
            'most_recent_flag' : 'T',
            'context_flag' : 'C',
            'freeze_off_flag' : 'off',
            'freeze_on_flag' : 'on',
        }

        for s in settings:
            if vim.eval("!exists('g:ozzy_%s')" % s) == '1':
                if isinstance(settings[s], str):
                    vim.command("let g:ozzy_%s = %r" % (s, settings[s]))
                else:
                    vim.command("let g:ozzy_%s = %s" % (s, settings[s]))
        # }}}

    def check_user_settings(self): # {{{          
        if any((
            Utils.setting('mode') not in self.MODES,
            Utils.setting('max_num_files_to_open', fmt=int) < 0,
            Utils.setting('open_files_recursively', fmt=int) < 0,
            Utils.setting('keep', fmt=int) < 0,
            )):

            msg = ("ozzy log: some setting has not been setted properly. "
                "Something may not work as expected.")
            Utils.echom(msg)
    # }}}

## helpers

    def find_fname_match(self, target): # {{{           
        matches = []
        for r in self.db.values():
            fname = os.path.split(r.path)[1]
            fname_no_ext = os.path.splitext(fname)[0]

            if Utils.setting('ignore_case', fmt=int):
                fname = fname.lower()
                fname_no_ext = fname_no_ext.lower()

            cond1 = target == fname 
            cond2 = (Utils.setting('ignore_ext', fmt=bool) 
                     and fname_no_ext == target)
            if cond1 or cond2:
                matches.append(r)

        return matches        
    # }}}

    def find_path_match(self, target): # {{{           
        matches = []
        for r in self.db.values():
            if Utils.setting('ignore_case', fmt=int):
                path = r.path.lower()
            else:
                path = r.path

            path_no_ext = os.path.splitext(path)[0]
            cond1 = path.endswith(target)
            cond2 = (Utils.setting('ignore_ext', fmt=bool) 
                     and path_no_ext.endswith(target))
            if cond1 or cond2:
                matches.append(r)

        return matches    
    # }}}

    def find_path_endswith(self, target): # {{{       
        if Utils.setting('open_files_recursively', fmt=int):
            return [record for record in self.db.values()
                    if target[:-1] in record.path.split('/')]
        else:
            return [record for record in self.db.values()
                    if os.path.split(record.path)[0].endswith(target[:-1])] 
    # }}}

    def find_path_contains(self, target): # {{{        
        target = target.strip('/')
        return [path for path, _, _ in records 
                if '/' + target in os.path.split(path)[0]]
    # }}}

    def find_matches_distance(self, target): # {{{        
        """Returns all matches and their relative distance to cwd"""
        matches = self.find_fname_match(target.strip())        
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

    def remove_from_db_if(self, func, getter): # {{{         
        nremoved = 0
        for record in self.db.values():
            if func(getter(record)):
                del self.db[record.path]
                nremoved += 1
        return nremoved  
    # }}}

    def match_patterns(self, target, patterns): # {{{            
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

    def print_current_mode(self): # {{{             
        Utils.feedback('mode %s' % Utils.setting('mode'))
    # }}}

    def print_current_freeze_status(self): # {{{         
        if Utils.setting('freeze', fmt=bool):
            Utils.feedback('freeze on')
        else:
            Utils.feedback('freeze off')
    # }}}

    def print_current_extension_status(self): # {{{          
        if Utils.setting('ignore_ext', fmt=bool):
            Utils.feedback('ignore extensions')
        else:
            Utils.feedback('consider extensions')
    # }}}

    def db_maintenance(self): # {{{         
        """Remove deleted files or files not recently opened (see g:ozzy_keep)"""
        for r in self.db.values():
            ozzy_keep = Utils.setting('keep', fmt=int)
            cond1 = not os.path.exists(r.path)  # remove non exitent files
            cond2 = (ozzy_keep > 0 and (dt.now() - r.last_access > 
                                        datetime.timedelta(days=ozzy_keep)))
            if cond1 or cond2:
                del self.db[r.path] 
    # }}}

    def remove_unlisted_buffers(self): # {{{ 
        listed_buf = [bname for bname in Utils.listed_buffers()]
        for b in self.buffers: 
            if b not in listed_buf:
                self.buffers.remove(b) 
    # }}}

    def update_buffer(self, bufname=None): # {{{         
        """Update the attributes of the current opened file in the database.

        This function is called whenever a buffer is read (on BufReadPost vim 
        event).
        """
        if bufname is None:
            bufname = vim.current.buffer.name  

        if (Utils.setting('freeze', fmt=bool) 
            or os.path.split(bufname)[1] == self.insp.name):
            return
        _cond = not self.match_patterns(bufname, Utils.setting('ignore')) 
        if _cond and bufname not in self.buffers:
            if bufname in self.db:
                self.db[bufname] = Record(bufname, self.db[bufname].frequency + 1, dt.now())
            else: 
                self.db[bufname] = Record(bufname, 1, dt.now())

            self.buffers.append(bufname)
            self.db.sync()
    # }}}

    def close(self): # {{{              
        self.db_maintenance()
        self.db.close() 
    # }}}

## interface functions

    # OzzyOpen {{{           
    def OzzyOpen(self, target):
        """Open the given file according to the current mode.
        
        If a directory name is given, all files in that direcotory are opened.
        """
        target = target.strip()
        attr = ('frequency' if Utils.setting('mode') in ['most_frequent', 'context'] 
                else 'last_access')

        if target.endswith('/'): 
            # open all files in the given directory
            matches = self.find_path_endswith(target)
            
            n = Utils.setting('max_num_files_to_open', fmt=int)
            if n > 0:
                paths = [r.path for r in nlargest(n, matches, key=attrgetter(attr))]
            else:
                paths =  [r.path for r in matches]

            if matches:
                vim.command("args " + ' '.join(Utils.escape_spaces(p) for p in paths))
                Utils.feedback('%d files opened' % len(paths))
            else:
                Utils.feedback('No file found')
        else: 
            # open a single file

            if '/' in target:
                matches = self.find_path_match(target)
            elif Utils.setting('mode') == 'context':
                # sort matches by distance: the closests first
                _matches = sorted(self.find_matches_distance(target), 
                                key=lambda t: t[1])

                if _matches:
                    minim = _matches[0][1]  # get the distance of the fist match
                    # sort closests matches by frequency: most accessed first
                    match = max([match for match, n in _matches if n == minim],
                                key=attrgetter(attr))
                    vim.command("e " + Utils.escape_spaces(match.path))
                else:
                    Utils.feedback('No file found') 

                return
            else:
                matches = self.find_fname_match(target)  

            if matches:
                record = max(matches, key=attrgetter(attr))
                vim.command("e %s" % Utils.escape_spaces(record.path))
            else:
                Utils.feedback('No file found')   
    # }}}

    # OzzyRemove {{{                
    def OzzyRemove(self, target):  # sync needed
        """To remove records from the database according to the given pattern."""
        t = target.strip()
        if t.startswith('*.'):
            nremoved = self.remove_from_db_if(
                lambda path: path.endswith(t[1:]), attrgetter('path'))

        elif t.endswith('.*'):
            nremoved = self.remove_from_db_if(
                lambda path: os.path.split(path)[1].startswith(target[:-2]),
                attrgetter('path')) 

        elif t.endswith('/'):
            nremoved = self.remove_from_db_if(
                lambda path: t in path, attrgetter('path')) 

        else:
            nremoved = self.remove_from_db_if(
                lambda path: os.path.split(path)[1] == t, attrgetter('path'))

        self.db.sync()
        self.insp.update_rendering()
        Utils.feedback('%d files removed' % nremoved)
    # }}}

    # OzzyKeepLast {{{                 
    def OzzyKeepLast(self, args): # sync needed 
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
            Utils.feedback('Bad argument!')
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
            Utils.feedback('Bad argument!')
            return

        nremoved = self.remove_from_db_if(
                    lambda time: 
                        (dt.now() - time) > datetime.timedelta(**delta),
                    attrgetter('last_access'))

        self.db.sync()
        self.insp.update_rendering()

        Utils.feedback('%d files removed' % nremoved)
    # }}}

    # OzzyReset {{{                          
    def OzzyReset(self): # sync needed
        """To clear the entire database."""

        answer = vim.eval("input('Are you sure? (yN): ')")
        vim.command('redraw') # to clear the command line
        if answer in ['y', 'Y', 'yes', 'Yes']:
            self.db.clear() 
            Utils.feedback('Database successfully cleared!')
        else:
            Utils.feedback('Database untouched!')

        self.db.sync()
        self.insp.update_rendering()
    # }}}

    # OzzyInspect {{{                      
    def OzzyInspect(self):
        """Open the database inpsector."""
        self.insp.open()     
    # }}}

    # OzzyAddDirectory {{{                 
    def AddDirectory(self, args): # sync needed

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

                    if (not self.match_patterns(path, Utils.setting('ignore')) 
                        and path not in self.db):

                        if ((not ignore_list
                            or not self.match_patterns(path, ignore_list))
                            and
                            (not add_list
                            or self.match_patterns(path, add_list))):

                            paths.append(path)

        msg = ("input('I''m going to add %d files, are you sure? (yN): ')" 
            % len(paths))
        answer = vim.eval(msg)
        vim.command('redraw') # to clear the command line
        if answer in ['y', 'Y', 'yes', 'Yes']:
            for p in paths:
                self.db[p] = Record(p, 1, dt.now())  
            Utils.feedback('%d files successfully added!' % len(paths))
        else:
            Utils.feedback('No files added!') 

        self.db.sync()
        self.insp.update_rendering()
    # }}}

    # ToggleMode {{{             
    def ToggleMode(self):
        # update inspector attribute to reflect this change when its opened
        curr_index = self.MODES.index(Utils.setting('mode'))
        if curr_index == len(self.MODES) - 1:
            next_mode = self.MODES[0]
        else:
            next_mode = self.MODES[curr_index + 1]
        Utils.let('mode', next_mode)
        self.insp.order_by = ('frequency' if Utils.setting('mode') == 'most_frequent' 
                              else 'last_access')  

        self.insp.update_rendering()
        self.print_current_mode()
    # }}}

    # ToggleFreeze {{{               
    def ToggleFreeze(self):
        Utils.let('freeze', value=not Utils.setting('freeze', fmt=bool))

        self.insp.update_rendering()
        self.print_current_freeze_status()
    # }}}

    # ToggleExtension {{{                
    def ToggleExtension(self):
        Utils.let('ignore_ext', value=not Utils.setting('ignore_ext', fmt=bool))

        self.insp.update_rendering()
        self.print_current_extension_status()
    # }}}

# }}}

# main object creation
# ===========================================================================
ozzy = Ozzy()

END

" Cmdline_completion {{{          
function! Cmdline_completion(seed, cmdline, curpos)
python << END
seed = vim.eval('a:seed')

def get_matches(func=lambda x: x):
    return [r for r in ozzy.db.values() 
            if func(os.path.split(r.path)[1]).startswith(seed)]

if Utils.setting('ignore_case', fmt=int):
    matches = get_matches(func=lambda x: x.lower())  
else:
    matches = get_matches()

attr = ('frequency' if Utils.setting('mode') in ['most_frequent', 'context'] 
        else 'last_access')   
completions = [os.path.split(r.path)[1] for r in
                sorted(matches, key=attrgetter(attr), reverse=True)]

Utils.let('completions', list(set(completions)))
END
    return g:ozzy_completions
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
    au CursorMoved * python ozzy.insp.insert_line_indicator()
    au BufEnter * python ozzy.remove_unlisted_buffers()
    au BufNewFile,BufReadPost * python ozzy.update_buffer()
    au VimLeave * python ozzy.close()
augroup END 

" }}}

" commands {{{            
" ========================================================= 

command! OzzyInspect python ozzy.OzzyInspect()
command! -nargs=1 -complete=customlist,Cmdline_completion Ozzy python ozzy.OzzyOpen(<q-args>)
command! -nargs=+ OzzyAddDirectory python ozzy.AddDirectory(<q-args>)

command! -nargs=1 -complete=customlist,Cmdline_completion OzzyRemove python ozzy.OzzyRemove(<q-args>)
command! -nargs=+ OzzyKeepLast python ozzy.OzzyKeepLast(<q-args>)
command! OzzyReset python ozzy.OzzyReset()

command! OzzyToggleMode python ozzy.ToggleMode()
command! OzzyToggleFreeze python ozzy.ToggleFreeze()
command! OzzyToggleExtension python ozzy.ToggleExtension()

if g:ozzy_enable_shortcuts
    command! Oi python ozzy.OzzyInspect()
    command! -nargs=+ Oadd python ozzy.AddDirectory(<q-args>)
    command! -nargs=1 -complete=customlist,Cmdline_completion O python ozzy.OzzyOpen(<q-args>)
    command! -nargs=1 -complete=customlist,Cmdline_completion Orm python ozzy.OzzyRemove(<q-args>)
    command! -nargs=+ Okeep python ozzy.OzzyKeepLast(<q-args>)
endif       

" }}}
