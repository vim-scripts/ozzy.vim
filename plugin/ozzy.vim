" ============================================================================
" File: ozzy.vim
" Description: Files launcher
" Mantainer: Giacomo Comitti (https://github.com/gcmt)
" Url: https://github.com/gcmt/ozzy.vim
" License: MIT
" Version: 0.9.1
" Last Changed: 23 gen 2013
" ============================================================================


" init ----------------------------------------------------------- {{{

if exists("g:ozzy_loaded") || &cp || !has('python')
    finish
endif

let g:ozzy_loaded = 1
scriptencoding utf-8
setlocal encoding=utf-8

let g:ozzy_test_file = 'tests.py'
" hide OzzyTest command by default
if !exists('g:ozzy_debug')
    let g:ozzy_debug = 0
endif

" }}}

python << END

# -*- coding: utf-8 -*-

# imports --------------------------------------------------------------- {{{
import vim
import os
import math
import sqlite3
import datetime
from heapq import nlargest
from collections import namedtuple
from datetime import datetime as dt
from itertools import groupby, chain, ifilter
from operator import attrgetter, itemgetter, methodcaller
# }}}

# OzzyUtils ------------------------------------------------------------- {{{

class OzzyUtils(object):
    """Utility and helper functions."""

    @staticmethod
    def escape_spaces(s): # {{{
        """To escape spaces from filenames."""
        return s.replace(' ', '\ ')
    # }}}

    @staticmethod
    def echom(msg): # {{{
        vim.command(u'echom "{0}"'.format(msg))
    # }}}

    @staticmethod
    def feedback(msg): # {{{
        OzzyUtils.echom(u'[ozzy] ' + msg)
    # }}}

    @staticmethod
    def listed_buffers(): # {{{
        """Tor return a list of all vim listed buffers."""
        return [b.name.decode('utf-8') for b in vim.buffers
                if b.name and vim.eval("buflisted('{0}')".format(
                    b.name.decode('utf-8').encode('utf-8'))) == '1']
    # }}}

    @staticmethod
    def remove_dupes(lst): # {{{
        """To remove duplicates from a list mantaining the order."""
        seen = set()
        seen_add = seen.add
        return [x for x in lst if x not in seen and not seen_add(x)]
    # }}}

    @staticmethod
    def is_sublist(sublst, lst): # {{{
        n = len(sublst)
        return any((sublst == lst[i:i+n])
                    for i in xrange(len(lst) - n+1))
    # }}}

    @staticmethod
    def seconds(td): # {{{
        """Returns a datetime.timedelta object as seconds."""
        return td.seconds + td.days * 24 * 3600
    # }}}

    ## settings proxy functions

    @staticmethod
    def let(name, value): # {{{
        """To set a vim variable to a given value."""
        prefix = u'g:ozzy_'
        if isinstance(value, basestring):
            val = u"'{0}'".format(value)
        elif isinstance(value, bool):
            val = u"{0}".format(1 if value else 0)
        else:
            val = value
        vim.command(u"let {0} = {1}".format(prefix + name, val))
    # }}}

    @staticmethod
    def setting(name, fmt=str): # {{{
        """To get a vim variable with the given name."""
        prefix = u'g:ozzy_'
        raw_val = vim.eval(prefix + unicode(name, 'utf8'))
        if isinstance(raw_val, list):
            return raw_val
        elif fmt is bool:
            return True if raw_val == '1' else False
        elif fmt is str:
            return unicode(raw_val, 'utf8')
        else:
            try:
                return fmt(raw_val)
            except ValueError:
                return None
    # }}}

    ## main helpers

    @staticmethod
    def match_patterns(target, patterns): # {{{
        sep = os.path.sep
        for patt in patterns:
            if patt.startswith('*.'):
                if target.endswith(patt[1:]):
                    return True
            elif patt.endswith('.*'):
                fname = os.path.split(target)[1]
                if fname.startswith(patt[:-2]):
                    return True
            elif patt.endswith(os.path.sep):
                if OzzyUtils.is_sublist(patt.strip(sep).split(sep),
                                    target.strip(sep).split(sep)):
                    return True
            elif os.path.split(target)[1] == patt:
                return True

        return False
    # }}}

    @staticmethod
    def find_by_path(records, target): # {{{
        for r in records:
            if OzzyUtils.setting('ignore_case', fmt=int):
                path = r.path.lower()
                target = target.lower()
            else:
                path = r.path

            cond1 = r.path.startswith(OzzyUtils.setting('scope'))
            cond2 = path.endswith(target)
            path_no_ext = os.path.splitext(path)[0]
            cond3 = (OzzyUtils.setting('ignore_ext', fmt=bool)
                     and path_no_ext.endswith(target))
            if cond1 and (cond2 or cond3):
                yield r
    # }}}

    @staticmethod
    def find_by_fname(records, target): # {{{
        """To find matches according to the given target and global options.
        """
        for r in records:
            fname = os.path.split(r.path)[1]
            fname_no_ext = os.path.splitext(fname)[0]

            if OzzyUtils.setting('ignore_case', fmt=int):
                fname = fname.lower()
                target = target.lower()
                fname_no_ext = fname_no_ext.lower()

            cond1 = r.path.startswith(OzzyUtils.setting('scope'))
            cond2 = target == fname
            cond3 = (OzzyUtils.setting('ignore_ext', fmt=bool)
                     and fname_no_ext == target)
            if cond1 and (cond2 or cond3):
                yield r
    # }}}

    @staticmethod
    def find_paths_in_directory(records, target): # {{{
        sep = os.path.sep
        t = target.strip(sep).split(sep)
        return [r for r in records
                if (r.path.startswith(OzzyUtils.setting('scope'))
                    and OzzyUtils.is_sublist(t, r.path.split(sep)))]
    # }}}

    @staticmethod
    def find_project_root(path, what_in_root=None): # {{{
        """To find the current project root.

        The project root is the first directory along the current working
        directory path who contains any of the file or folders listed in the
        'what_in_root' list.
        """
        if what_in_root is None:
            what_in_root = OzzyUtils.setting('what_in_project_root')

        if path == os.path.sep:
            return None
        else:
            for d in os.listdir(path.decode('utf8')):
                if d in what_in_root:
                    return path
            return OzzyUtils.find_project_root(os.path.split(path)[0],
                                           what_in_root)
    # }}}

    @staticmethod
    def sort_by_distance(records, cwd=None, reverse=False): # {{{
        """To return all records sorted by distance relative to the cwd.

           Records are grouped by their relative distance (a list of lists is
           returned) in order to allow further ordering.
        """
        # r = [(distance, record), ...]
        r = list(OzzyUtils.decorate_with_distance(records, cwd))
        r.sort(key=itemgetter(0), reverse=reverse) # sort by distance
        groups = groupby(r, key=itemgetter(0)) # group by distance
        return [map(itemgetter(1), g) for k, g in groups] # discard keys
    # }}}

    @ staticmethod
    def decorate_with_distance(records, cwd=None): # {{{
        """To decorate the records with their relative distance to the cwd."""
        if cwd is None:
            cwd = vim.eval('getcwd()').decode('utf8')
        sep = os.path.sep

        for rec in records:
            if rec.path.startswith(cwd):
                p = rec.path[len(cwd):]  # remove cwd from path
                # get the number of directories between cwd and the the file
                x = (len(p.split(sep)[1:-1]), rec)
            else:
                cwd_lst = cwd.strip(sep).split(sep)
                path_lst = rec.path.strip(sep).split(sep)[:-1]

                for f1, f2 in zip(cwd_lst, path_lst):
                    if f1 == f2:
                        cwd_lst.remove(f1)
                        path_lst.remove(f1)

                x = (len(cwd_lst) + len(path_lst), rec)

            yield x # x is a tuple (distance, record)
    # }}}

    @staticmethod
    def sort_groups_by(groups, attr, flatten=False, reverse=True): # {{{
        """To sort the given gropus according to the given attribute.

           The 'groups' parameter is expected to be a list of lists (groups).
        """
        sorted_groups = [sorted(g, key=attrgetter(attr), reverse=reverse)
                         for g in groups]
        if flatten:
            return list(chain.from_iterable(sorted_groups))
        else:
            return sorted_groups
    # }}}

    @staticmethod
    def group_by_path(paths, path): # {{{
        """To group records according to the given path.

        every item in 'paths' is assumed to contain 'path.
        Example:
        >>> l = ['a/b', 'a/c/b', 'a/b/c', 'a/c/b/h']
        >>> group_by_path(l, 'b')
        [['a/b', 'a/b/c'], ['a/c/b', 'a/c/b/h']]
        """
        groups = groupby(sorted(paths, key=attrgetter('path')),
                         key=lambda r: r.path[:r.path.index(path)])
        return [list(g) for key, g in groups]
    # }}}

    @staticmethod
    def decorate_groups_mean(groups, ref): # {{{
        """pivot is a datetime object."""

        def mean(values):
            return sum(values) / len(values)

        return [(mean(map(lambda x: OzzyUtils.seconds(ref-x.last_access), g)), g)
                for g in groups]
    # }}}

    @staticmethod
    def get_cmdline_opt(option, arglist, expect_arg=True): # {{{
        """To extract an argument option from a list of arguments."""
        try:
            if expect_arg:
                return arglist[arglist.index(option) + 1]
            else:
                if option in arglist:
                    return True
                else: 
                    return False
        except (IndexError, ValueError):
            return None
    # }}}

# }}}

# OzzyDBProxy ----------------------------------------------------------- {{{

class OzzyDBProxy(object):
    """Database proxy."""

    def __init__(self, path_db): # {{{
        
        self.SCHEMA = """
            CREATE TABLE files_index (
                path string primary key,
                frequency integer not null,
                last_access timestamp not null
            );"""

        missing_db = not os.path.exists(path_db)
        self.conn = sqlite3.connect(path_db,
            detect_types=sqlite3.PARSE_DECLTYPES)
        self.Row = namedtuple('Row', "path frequency last_access")

        if missing_db: 
            self.conn.executescript(self.SCHEMA)
            self.conn.commit()
    # }}}

    def __contains__(self, path): # {{{       
        """Implements the 'in' operator behavior."""
        query = "SELECT * FROM files_index WHERE path=?"
        r = self.conn.execute(query, (path,)).fetchone()
        return True if r else False
    # }}}

    def all(self): # {{{      
        """To get all rows."""
        for row in self.conn.execute("SELECT * FROM files_index").fetchall():
            yield self.Row(*row)
    # }}}

    def get(self, path): # {{{       
        """To get a specific record given its path."""
        sql = "SELECT * FROM files_index WHERE path=?"
        row = self.conn.execute(sql, (path,)).fetchone()
        if row:
            return self.Row(*row)
    # }}}

    def add(self, path, frequency, last_access): # {{{        
        """To add a new record."""
        try:
            sql = "INSERT INTO files_index VALUES (?, ?, ?)"
            self.conn.execute(sql, (path, frequency, last_access))
        except:
            pass
        else:
            self.conn.commit()
    # }}}

    def add_many(self, paths, frequency, last_access): # {{{        
        """To add a bunch of new records at once."""
        try:
            sql = "INSERT INTO files_index VALUES (?, ?, ?)"
            self.conn.executemany(sql,
                [(path, frequency, last_access) for path in paths])
        except:
            pass

        self.conn.commit()
    # }}}

    def update(self, path, frequency=None, last_access=None): # {{{      
        """To update attributes of an existing record."""
        if frequency and not last_access:
            sql = "UPDATE files_index SET frequency=frequency+? WHERE path=?"
            self.conn.execute(sql, (frequency, path))
        elif last_access and not frequency:
            sql = "UPDATE files_index SET last_access=? WHERE path=?"
            self.conn.execute(sql, (last_access, path))
        elif frequency and last_access:
            sql = "UPDATE files_index SET frequency=frequency+?, last_access=? WHERE path=?"
            self.conn.execute(sql, (frequency, last_access, path))

        self.conn.commit()
    # }}}

    def delete(self, path): # {{{        
        """To delete a record given its path."""
        sql = "DELETE FROM files_index WHERE path=?"
        self.conn.execute(sql, (path,))
        self.conn.commit()
    # }}}

    def delete_many(self, paths): # {{{       
        """To delete a bunch of records given their paths."""
        sql = "DELETE FROM files_index WHERE path=?"
        self.conn.executemany(sql, [(path,) for path in paths])
        self.conn.commit()
    # }}}

    def delete_all(self): # {{{        
        """To delete all records from the database."""
        self.conn.execute("DELETE FROM files_index")
        self.conn.commit()
    # }}}

    def close(self): # {{{      
        """To close the database connection."""
        self.conn.close()
    # }}}

# }}}

# OzzyInspector --------------------------------------------------------- {{{

class OzzyInspector(object):
    """OzzyInspector definition."""

    def __init__(self, ozzy): # {{{
        self.ozzy = ozzy
        self.name = 'ozzy_inspector'
        self.reverse_order = True
        self.show_help = False
        self.short_paths = True
        self.cursor = [1, 0]
        self.last_path_under_cursor = ''
        self.mapper = {} # line to record mapper

        mode = OzzyUtils.setting('mode')
        if mode == 'most frequent':
            self.order_by = 'frequency'
        elif mode == 'most recent':
            self.order_by = 'last_access'
        else:
            self.order_by = u'context'

        # note about self.mapper:
        # when a user want to perform an action in the inspector buffer, he
        # moves the cursor on the line where the records of its interest is
        # positionated and the he perform the action action (pressing a
        # specific key). The mapper serves the purpose of mapping lines of
        # the nuffer with records displayed on them, so that the action
        # is performed on the right record.
    # }}}

    def open(self, order_by=None, reverse_order=None, show_help=None, # {{{
             short_paths=None):
        """Opens the inspector buffer."""
        # update the inspector environment if something has changed
        if order_by is not None:
            self.order_by = order_by
        if reverse_order is not None:
            self.reverse_order = reverse_order
        if show_help is not None:
            self.show_help = show_help
        if short_paths is not None:
            self.short_paths = short_paths

        # create the inspector buffer
        vim.command("e {0}".format(self.name))
        vim.command("let b:ozzy_inspector_opened=1")
        vim.command("setlocal buftype=nofile")
        vim.command("setlocal bufhidden=wipe")
        vim.command("setlocal encoding=utf-8")
        vim.command("setlocal noswapfile")
        vim.command("setlocal noundofile")
        vim.command("setlocal nobackup")
        vim.command("setlocal nowrap")
        vim.command("setlocal modifiable")
        self.render()
        self.map_keys()
        vim.command("setlocal nomodifiable")
    # }}}

    def render(self): # {{{
        """Render the inspector buffer content."""
        self.mapper.clear()
        b = vim.current.buffer
        b[:] = None

        if self.order_by == u'context':
            groups = OzzyUtils.sort_by_distance(self.ozzy.db.all(),
                            reverse=not self.reverse_order)

            records = OzzyUtils.sort_groups_by(groups, 'last_access',
                            flatten=True, reverse=self.reverse_order)
        else:
            records = sorted(self.ozzy.db.all(),
                             key=attrgetter(self.order_by),
                             reverse=self.reverse_order)

        b.append('  >> Ozzy OzzyInspector (type ? for help)')

        if self.show_help:
            help = [
                '',
                '  ▸ help',
                '    ----------------------------------',
                '    q : quit inspector',
                '    ? : toggle help',
                '    s : set the scope to the directory who contains the file on the current line', 
                '    g : set the global scope',
                '    x : scope filtering: show only files in the current scope', 
                '    z : hide the scope from paths (works only if scope filtering is active)', 
                '    e : show/hide ozzy and inspector settings', 
                '    p : toggle between absolute and relative-to-home paths',
                '    f : order records by frequency',
                '    a : order records by last access date and time',
                '    c : order records by distance relative to the current working directory',
                '    r : reverse the current order',
                '    o : open the file on the current line',
                '    b : open in background the file on the current line',
                '    + : increase the frequency of the file on the current line',
                '    - : decrease the frequency of the file on the current line',
                '    t : touch the file on the current line (set its ''last access attribute'' to now)',
                '    dd : remove from the list the record under the cursor (or an entire selection)',
                '         For additional power see OzzyRemove, OzzyKeepLast and OzzyReset commands'
            ]

            for l in help:
                b.append(l)

        # print records

        mode = OzzyUtils.setting('mode')

        if OzzyUtils.setting('ignore_ext', fmt=bool):
            extensions = 'ignore'
        else:
            extensions = 'consider'

        if OzzyUtils.setting('freeze', fmt=bool):
            freeze = 'on'
        else:
            freeze = 'off'

        if OzzyUtils.setting('filter_inspector_by_scope', fmt=bool):
            filter_by_scope = 'on'
        else:
            filter_by_scope = 'off'

        if OzzyUtils.setting('hide_scope_inspector', fmt=bool):
            hide_scope = 'on'
        else:
            hide_scope = 'off'

        s = OzzyUtils.setting('scope')
        scope = s if s else 'global'
        if self.short_paths:
            scope = scope.replace(os.path.expanduser('~'), '~')

        cwd = vim.eval('getcwd()')
        if self.short_paths:
            cwd = cwd.replace(os.path.expanduser('~'), '~')

        def _make_order(otype, msg_rev, msg_norev):
            d = {'type': otype}
            if self.reverse_order:
                d.update({'rev': msg_rev})
            else:
                d.update({'rev': msg_norev})
            return d

        if self.order_by == u'context':
            order = _make_order('distance', 'closest', 'farthest')
        elif self.order_by == u'frequency':
            order = _make_order('frequency', 'most frequent', 'least frequent')
        elif self.order_by == u'last_access':
            order = _make_order('access time', 'most recent', 'least recent')

        if OzzyUtils.setting('show_env_inspector', fmt=bool):
            b.append('')
            b.append('  + ozzy settings:')
            b.append('  ├─ mode ......... {0}'.format(mode))
            b.append('  ├─ freeze ....... {0}'.format(freeze))
            b.append('  ├─ extensions ... {0}'.format(extensions))
            b.append('  ├─ scope ........ {0}'.format(scope))
            b.append('  └─ cwd .......... {0}'.format(cwd))
            b.append('')
            b.append('  + inspector settings:')
            b.append('  ├─ order ........ {type}, {rev} first'.format(**order))
            b.append('  ├─ filter scope . {0}'.format(filter_by_scope))
            b.append('  └─ hide scope ... {0}'.format(hide_scope))

        b.append('')
        b.append("  last access          freq   dist   file path")
        b.append("  -------------------  -----  -----  ---------------")

        if filter_by_scope == 'on':
            records = [r for r in records 
                       if r.path.startswith(OzzyUtils.setting('scope'))]

        for dist, r in OzzyUtils.decorate_with_distance(records):
            last_access = r.last_access.strftime('%Y-%m-%d %H:%M:%S')
            scope = OzzyUtils.setting('scope')
            if filter_by_scope == 'on' and hide_scope == 'on' and scope != '':
                path = r.path.replace(scope + os.path.sep, '')
            elif self.short_paths:
                path = r.path.replace(os.path.expanduser('~'), '~')
            else:
                path = r.path
            b.append("  {0} {1:>6} {2:>6}  {3}".format(last_access, r.frequency,
                                               dist, path.encode('utf8')))

            # map the record path to the line it has been printed
            self.mapper[len(b)] = r.path

        # adjust cursor position

        if not records:
            b.append('')
            self.cursor = [len(b), 2]
        elif self.cursor[0] not in self.mapper:
            # move the cursor to the forst position of the records list
            self.cursor = [min(self.mapper), 0]
        else:
            # prevent the cursor to be moved to a non-existent position
            if self.cursor[0] > len(b):
                self.cursor = [len(b), 0]
            else:
                # follow the previous modified record
                line = self.get_line_last_path()
                if line:
                    self.cursor[0] = line

        vim.current.window.cursor = self.cursor

        self.insert_line_indicator()
    # }}}

    def map_keys(self): # {{{           
        """To create mappings for the inpector buffer."""
        mappings = (
            'q :b#<BAR>bd#', # close buffer without closing the window
            'f :python ozzy.insp.open(order_by=u"frequency")',
            'a :python ozzy.insp.open(order_by=u"last_access")',
            'c :python ozzy.insp.open(order_by=u"context")',
            'o :python ozzy.insp.open_record()',
            'b :python ozzy.insp.open_record(bg=True)',
            's :python ozzy.insp.set_scope()',
            'x :python ozzy.insp.toggle_filter_scope()',
            'z :python ozzy.insp.toggle_hide_scope()',
            'e :python ozzy.insp.toggle_show_env()',
           'dd :python ozzy.insp.delete_records()',
            '+ :python ozzy.insp.update_freq_record(1)',
            '- :python ozzy.insp.update_freq_record(-1)',
            '* :python ozzy.insp.update_freq_record(5)',
            '_ :python ozzy.insp.update_freq_record(-5)',
            't :python ozzy.insp.touch_record()',
           ('r :python ozzy.insp.open(reverse_order={0})'
             .format(not self.reverse_order)),
            ('p :python ozzy.insp.open(short_paths={0})'
             .format(not self.short_paths)),
            ('? :python ozzy.insp.open(show_help={0})'
             .format(not self.show_help)),
        )

        for m in mappings:
            vim.command('nnoremap <buffer> <silent> ' + m + '<CR>')

        vim.command('vnoremap <buffer> <silent> '
                    'dd :python ozzy.insp.delete_records()<CR>')
    # }}}

    def update_rendering(self): # {{{
        """To render the buffer only if it is already opened."""
        if self.opened():
            vim.command("setlocal modifiable")
            self.render()
            vim.command("setlocal nomodifiable")
    # }}}

    def follow_record(self): # {{{
        """To ensure tath the cursor follows a record when it is modified.

           When a record is modified, the inspector is rendered again so that
           some feedback is given to the user about what has changed.  Due to
           the fact that records ordering in the inspector is always active, it
           might happen that the record changes its position in the records
           list when it is modified (e.g. incremented frequency when the
           records list is ordered by frequency). This method ensure that the
           cursor will follow the current modified record.
        """
        line, col = vim.current.window.cursor
        self.cursor = [line, col]
        if line in self.mapper:
            self.last_path_under_cursor = self.mapper[line]
    # }}}

    def opened(self): # {{{
        """To check if the inspector buffer is opened."""
        return vim.eval("exists('b:ozzy_inspector_opened')") == '1'
    # }}}

    def get_line_last_path(self): # {{{
        for line, path in self.mapper.items():
            if path == self.last_path_under_cursor:
                return line
    # }}}

    def insert_line_indicator(self): # {{{
        """To insert a little arrow on the line where the cursor is positionated.
        """
        if not self.opened():
            return

        b = vim.current.buffer
        if len(b) > 1:
            vim.command("setlocal modifiable")
            curr_linenr, _ = vim.current.window.cursor
            indicator = '▸'  #'●'

            for linenr in self.mapper:
                if linenr > 1 and linenr == curr_linenr:
                    if indicator not in b[linenr-1]:
                        b[linenr-1] = indicator + b[linenr-1][1:]
                else:
                    b[linenr-1] = b[linenr-1].replace(indicator, ' ')

            vim.command("setlocal nomodifiable")
    # }}}

    def get_path_on_line(self, line=None): # {{{
        """To get the path mapped with the given line."""
        line = line if line else vim.current.window.cursor[0]
        return self.mapper.get(line, None)
    # }}}

    def delete_records(self): # {{{
        """To delete the selected records from the database.

        This function automatically detects if a selection has been made by the
        user and if so all the selected records are deleted.
        """
        start = vim.current.buffer.mark('<')
        end = vim.current.buffer.mark('>')
        if start is None: # there is no range
            path = self.get_path_on_line()
            if path:
                self.ozzy.db.delete(path)
            self.cursor = list(vim.current.window.cursor)
        else:
            paths = ifilter(None, [self.get_path_on_line(line)
                                   for line in xrange(start[0], end[0]+1)])
            self.ozzy.db.delete_many(paths)
            vim.command('delmarks <>')
            self.cursor = list(start)

        self.follow_record()
        self.update_rendering()
    # }}}

    def touch_record(self): # {{{
        """To set to now the access time of the record on the current line."""
        path = self.get_path_on_line()
        if path:
            self.ozzy.db.update(path, last_access=dt.now())

        self.follow_record()
        self.update_rendering()
    # }}}

    def update_freq_record(self, n): # {{{
        """To increment the frequency of the record on the current line."""
        path = self.get_path_on_line()
        if path:
            if n < 0 and self.ozzy.db.get(path).frequency <= abs(n):
                # frequency cannot be setted to a value <= 0
                return
            else:
                self.ozzy.db.update(path, frequency=n)

        self.follow_record()
        self.update_rendering()
    # }}}

    def open_record(self, bg=False): # {{{
        """To open the file (record) on the current line."""
        path = self.get_path_on_line()
        if path:
            if bg:
                self.ozzy.update_buffer(path)
                vim.command('bad {0}'.format(
                    OzzyUtils.escape_spaces(path).encode('utf-8')))
                self.follow_record()
                self.update_rendering()
            else:
                vim.command('e {0}'.format(
                    OzzyUtils.escape_spaces(path).encode('utf-8')))
                pass
    # }}}

    def set_scope(self): # {{{
        """Sets the scope to the directory who contains the file (record) on 
        the current line."""
        path = self.get_path_on_line()
        if path:
            OzzyUtils.let('scope', value=os.path.split(path)[0])

        self.follow_record()
        self.update_rendering()
    # }}}

    def toggle_filter_scope(self): # {{{
        OzzyUtils.let('filter_inspector_by_scope',
            value=not OzzyUtils.setting('filter_inspector_by_scope', fmt=bool))

        self.follow_record()
        self.update_rendering()
    # }}}

    def toggle_hide_scope(self): # {{{
        OzzyUtils.let('hide_scope_inspector',
            value=not OzzyUtils.setting('hide_scope_inspector', fmt=bool))

        self.follow_record()
        self.update_rendering()  
    # }}}

    def toggle_show_env(self): # {{{
        OzzyUtils.let('show_env_inspector',
            value=not OzzyUtils.setting('show_env_inspector', fmt=bool))

        self.follow_record()
        self.update_rendering()  
    # }}}

# }}}

# Ozzy ------------------------------------------------------------------ {{{

class Ozzy(object):
    """Main ozzy class."""

    def __init__(self): # {{{           
        self.init_settings()

        self.PLUGIN_PATH = vim.eval("expand('<sfile>:h')").decode('utf8')
        self.SCHEMA_PATH = os.path.join(self.PLUGIN_PATH, 'schema.sql')

        # set the path for the database location
        user_db_path = OzzyUtils.setting('db_path')
        if user_db_path:
            self.DB_PATH = os.path.join(user_db_path, 'ozzy.db')
            OzzyUtils.let('db_path', user_db_path)
        else:
            self.DB_PATH = os.path.join(self.PLUGIN_PATH, 'ozzy.db')

        self.opened_buffers = [] # to keep track of opened buffers
        self.MODES = [u'most frequent', u'most recent', u'context']
        self.db = OzzyDBProxy(self.DB_PATH)
        self.insp = OzzyInspector(self)
        self.scope_default = OzzyUtils.setting('scope')
    # }}}

    def init_settings(self): # {{{
        settings = {
            'mode' : 'most frequent',
            'db_path': '',
            'freeze' : 0,
            'ignore_ext' : 1,
            'ignore' : [],
            'keep' : 0,
            'scope' : '',
            'enable_shortcuts' : 1,
            'max_num_files_to_open' : 0,
            'filter_inspector_by_scope' : 0,
            'hide_scope_inspector' : 0,
            'show_inspector_env' : 1,
            'ignore_case' : 0,
            'what_in_project_root' : ['.git', '.hg', '.svn'],
            'most_frequent_flag' : 'F',
            'most_recent_flag' : 'T',
            'context_flag' : 'C',
            'freeze_off_flag' : 'off',
            'freeze_on_flag' : 'on',
        }

        for s in settings:
            if vim.eval("!exists('g:ozzy_{0}')".format(s)) == '1':
                OzzyUtils.let(s, settings[s])
    # }}}

    def remove_from_db_if(self, func, getter): # {{{
        """To remove records from the database according to the 'func'
        function."""
        l = [r.path for r in self.db.all() if func(getter(r))]
        self.db.delete_many(l)
        return len(l)
    # }}}

    def print_mode(self): # {{{
        OzzyUtils.feedback(u'mode: {0}'.format(OzzyUtils.setting('mode')))
    # }}}

    def print_scope(self): # {{{
        scope = OzzyUtils.setting('scope')
        if scope == '':
            OzzyUtils.feedback('scope: global')
        else:
            OzzyUtils.feedback('scope: {0}'.format(scope))
    # }}}

    def print_freeze_status(self): # {{{
        if OzzyUtils.setting('freeze', fmt=bool):
            OzzyUtils.feedback('freeze on')
        else:
            OzzyUtils.feedback('freeze off')
    # }}}

    def print_extension_status(self): # {{{
        if OzzyUtils.setting('ignore_ext', fmt=bool):
            OzzyUtils.feedback('ignore extensions')
        else:
            OzzyUtils.feedback('consider extensions')
    # }}}
    
    def print_fiter_inspector_status(self): # {{{
        if OzzyUtils.setting('filter_inspector_by_scope', fmt=bool):
            OzzyUtils.feedback('filter inspector by scope: on')
        else:
            OzzyUtils.feedback('filter inspector by scope: off')
    # }}}

    def db_maintenance(self): # {{{
        """To remove deleted files or files not recently opened."""
        l = []
        for r in self.db.all():
            ozzy_keep = OzzyUtils.setting('keep', fmt=int)
            cond1 = not os.path.exists(r.path)  # remove non exitent files
            cond2 = (ozzy_keep > 0 and (dt.now() - r.last_access >
                                        datetime.timedelta(days=ozzy_keep)))
            if cond1 or cond2:
                l.append(r.path)

        self.db.delete_many(l)
    # }}}

    def remove_unlisted_buffers(self): # {{{
        """To remove unlisted buffer from the internal buffer list."""
        listed_buf = OzzyUtils.listed_buffers()
        for buf in self.opened_buffers:
            if buf not in listed_buf:
                self.opened_buffers.remove(buf)
    # }}}

    def update_buffer(self, bufname=None): # {{{
        """Update in the database the attributes of the current opened buffer.

        This method is called whenever a buffer is read (BufNewFile and
        BufReadPost vim events).

        TODO: (lazy updates) using collections.Counter or a simple dictionary
        to keep track of buffers updates could prehaps improves the overall
        performaces?

        A Counter/dict object is keeped in memory. Two approaches may be
        viable in order to update the database:
        1. every time an Ozzy command is executed
        2. when the counter or dict size reach a certain size

        pitfalls:
        1. how to deal with last access time when using Counter?
        """
        if OzzyUtils.setting('freeze', fmt=bool) or self.insp.opened():
            return

        if bufname is None:
            bufname = vim.current.buffer.name.decode('utf-8')

        if (bufname.startswith(OzzyUtils.setting('scope'))
            and bufname not in self.opened_buffers
            and not OzzyUtils.match_patterns(bufname, OzzyUtils.setting('ignore'))):

            if bufname in self.db:
                self.db.update(bufname, +1, dt.now())
            else:
                self.db.add(bufname, 1, dt.now())
            self.opened_buffers.append(bufname)
    # }}}

    def close(self): # {{{
        self.db_maintenance()
        self.db.close()
    # }}}

    ## interface methods

    def OzzyInspect(self): # {{{
        """Open the database inpsector."""
        self.insp.open()
    # }}}

    def OzzyOpen(self, arg): # {{{
        """Open the given file according to the current mode.

        If a directory name is given, all files in that directory are opened.
        """
        target = arg.decode('utf8')

        attr = (u'last_access'
                if OzzyUtils.setting('mode') in [u'most recent', u'context']
                else u'frequency')

        if target.endswith(os.path.sep):
            # open all files in the given directory
            matches = OzzyUtils.find_paths_in_directory(self.db.all(), target)

            groups = OzzyUtils.group_by_path(matches, target.strip(os.path.sep))

            # For each group, this method:
            # 1. takes all its records
            # 2. for every record computes the time delta (in seconds) between
            #    now (dt.now()) and its last_access attribute
            # 3. computes the mean of all the time deltas
            # 4. decorate each group with the relative mean
            #
            _groups = OzzyUtils.decorate_groups_mean(groups, dt.now())

            # select the group who has the minimum mean
            if _groups:
                m = min(_groups, key=itemgetter(0))[1]
            else:
                m = []

            n = OzzyUtils.setting('max_num_files_to_open', fmt=int)
            if n > 0:
                paths = [r.path for r in
                         nlargest(n, m, key=attrgetter(attr))]
            else:
                paths =  [r.path for r in m]

            if matches:
                for p in paths:
                    self.update_buffer(p)
                    vim.command('99argadd {0}'.format(
                        OzzyUtils.escape_spaces(p).encode('utf-8')))
                self.insp.update_rendering()
                OzzyUtils.feedback(u'{0} files opened'.format(len(paths)))
            else:
                OzzyUtils.feedback(u'nothing found')
        else:
            # open a single file

            if os.path.sep in target:
                matches = list(OzzyUtils.find_by_path(self.db.all(), target))

            elif OzzyUtils.setting('mode') == u'context':
                # sort and group records by distance
                groups = OzzyUtils.sort_by_distance(
                            OzzyUtils.find_by_fname(self.db.all(), target))

                matches = OzzyUtils.sort_groups_by(groups, 'last_access',
                                               flatten=True)
                if matches:
                    vim.command('e {0}'.format(
                        OzzyUtils.escape_spaces(matches[0].path).encode('utf8')))
                else:
                    OzzyUtils.feedback(u'nothing found')
                return

            else:
                matches = list(OzzyUtils.find_by_fname(self.db.all(), target))

            if matches:
                record = max(matches, key=attrgetter(attr))
                vim.command('e {0}'.format(
                    OzzyUtils.escape_spaces(record.path).encode('utf8')))
            else:
                OzzyUtils.feedback(u'nothing found')
    # }}}

    def OzzyRemove(self, patt): # {{{
        """To remove records from the database according to the given pattern."""
        if patt == '%':
            patt = os.path.split(vim.current.buffer.name)[1]
            nremoved = self.remove_from_db_if(
                lambda path: os.path.split(path)[1] == patt, attrgetter('path'))

        elif patt.startswith('*.'):
            nremoved = self.remove_from_db_if(
                lambda path: path.endswith(patt[1:]), attrgetter('path'))

        elif patt.endswith('.*'):
            nremoved = self.remove_from_db_if(
                lambda path: os.path.split(path)[1].startswith(patt[:-2]),
                attrgetter('path'))

        elif patt.endswith(os.path.sep):
            nremoved = self.remove_from_db_if(
                lambda path: patt in path, attrgetter('path'))

        else:
            nremoved = self.remove_from_db_if(
                lambda path: os.path.split(path)[1] == patt, attrgetter('path'))

        self.insp.update_rendering()
        OzzyUtils.feedback(u'{0} files removed'.format(nremoved))
    # }}}

    def OzzyKeepLast(self, args): # {{{
        """Remove all records according to the given period of time.

        The period of time might be expressed in minutest, hours, days or weeks.
        Examples: 30 minutes, 3 hours, 1 day, 2 weeks
        If a there is a file in the database that has not been opened in the last n
        minutes/hours/days/weeks is removed.
        """
        try:
            n, what = args.split()
            n = int(n)
            if n < 0:
                raise ValueError
        except ValueError:
            OzzyUtils.feedback(u'bad argument!')
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
            OzzyUtils.feedback(u'bad argument!')
            return

        nremoved = self.remove_from_db_if(
                    lambda time:
                        (dt.now() - time) > datetime.timedelta(**delta),
                    attrgetter('last_access'))

        self.insp.update_rendering()

        OzzyUtils.feedback('{0} files removed'.format(nremoved))
    # }}}

    def OzzyReset(self): # {{{
        """To clear the entire database."""
        answer = vim.eval("input('Are you sure? (yN): ')")
        vim.command('redraw') # to clear the command line
        if answer in ['y', 'Y', 'yes', 'Yes']:
            self.db.delete_all()
            OzzyUtils.feedback(u'database successfully cleared!')
        else:
            OzzyUtils.feedback(u'database untouched!')

        self.insp.update_rendering()
    # }}}

    def OzzyAddDirectory(self, args): # {{{
        """To add all files contained in a given directory."""
        # return true if cur_root is not a directory contained into an hidden
        # directory
        def into_hidden_dir(cur_root, topdir):
            s = cur_root.replace(topdir, '')
            return any([t.startswith('.') for t in s.split(os.path.sep)])

        arglist = args.split()

        # extract options from the argument list

        opt = OzzyUtils.get_cmdline_opt('-a', arglist)
        if opt:
            add = opt.strip(',').split(',')
        else:
            add = []

        opt = OzzyUtils.get_cmdline_opt('-i', arglist)
        if opt:
            ignore = opt.strip(',').split(',')
        else:
            ignore = []

        add_hidden_dirs = OzzyUtils.get_cmdline_opt('-h', arglist, expect_arg=False)

        topdir = arglist[0]
        if topdir == '.':
            topdir = vim.eval('getcwd()')

        elif topdir == '..':
            topdir = os.path.split(vim.eval('getcwd()'))[0]

        elif topdir == '...':
            opt = OzzyUtils.get_cmdline_opt('-p', arglist)
            if opt:
                what_in_root = opt.strip(',').split(',')
            else:
                what_in_root = OzzyUtils.setting('what_in_project_root')

            topdir = OzzyUtils.find_project_root(vim.eval('getcwd()'), what_in_root)

            if not topdir:
                OzzyUtils.feedback(u'project root not found')
                return

        # find all files

        if os.path.exists(topdir):
            paths = []
            for root , dirs, files in os.walk(topdir.decode('utf-8')):
                if (add_hidden_dirs
                    or not into_hidden_dir(root, topdir)):

                    for f in files:
                        path = os.path.join(root, f)

                        if (not OzzyUtils.match_patterns(path, OzzyUtils.setting('ignore'))
                            and path not in self.db):

                            if ((not ignore
                                or not OzzyUtils.match_patterns(path, ignore))
                                and
                                (not add
                                or OzzyUtils.match_patterns(path, add))):

                                paths.append(path)

            if paths:
                msg = ("input('%d files found, are you sure? (yN): ')"
                    % len(paths))
                answer = vim.eval(msg)
                vim.command('redraw') # to clear the command line
                if answer in ['y', 'Y', 'yes', 'Yes']:
                    self.db.add_many(paths, 1, dt.now())
                    OzzyUtils.feedback('{0} files successfully added!'.format(len(paths)))
                else:
                    OzzyUtils.feedback(u'no files added!')
            else:
                OzzyUtils.feedback(u'nothig found')

            self.insp.update_rendering()

        else:
            OzzyUtils.feedback(u'directory not found')

    # }}}

    def OzzyScope(self, scope): # {{{
        if not scope:
            s = self.scope_default
        elif scope == '.':
            s = vim.eval('getcwd()')
        elif scope == '..':
            s = os.path.split(vim.eval('getcwd()'))[0]
        elif scope == '...':
            opt = OzzyUtils.get_cmdline_opt('-p', args.split())
            if opt:
                what_in_root = opt.strip(',').split(',')
            else:
                what_in_root = OzzyUtils.setting('what_in_project_root')

            s = OzzyUtils.find_project_root(vim.eval('getcwd()'), what_in_root)

            if not s:
                OzzyUtils.feedback(u'project root not found')
                return
        else:
            if os.path.exists(scope):
                s = scope
            else:
                OzzyUtils.feedback('path does not exist')
                return

        OzzyUtils.let('scope', s)
        self.print_scope()
        self.insp.update_rendering()
    # }}}

    def ToggleMode(self): # {{{
        """To toggle between available modes."""
        # update inspector attribute to reflect this change when its opened
        curr_index = self.MODES.index(OzzyUtils.setting('mode'))
        if curr_index == len(self.MODES) - 1:
            next_mode = self.MODES[0]
        else:
            next_mode = self.MODES[curr_index + 1]

        OzzyUtils.let(u'mode', next_mode)
        self.insp.update_rendering()
        self.print_mode()
    # }}}

    def ToggleFreeze(self): # {{{
        """To toggle the freeze status."""
        OzzyUtils.let(u'freeze', value=not OzzyUtils.setting('freeze', fmt=bool))

        self.insp.update_rendering()
        self.print_freeze_status()
    # }}}

    def ToggleExtension(self): # {{{
        """To toggle the consider/ignore extension status."""
        OzzyUtils.let(u'ignore_ext', 
                  value=not OzzyUtils.setting('ignore_ext', fmt=bool))

        self.insp.update_rendering()
        self.print_extension_status()
    # }}}

# execute tests
# ---------------------------------------------------------
    def _test(self): # {{{
        """Executes tests for Ozzy. See OzzyTest command."""
        fname = OzzyUtils.setting('test_file')
        path = os.path.join(self.PLUGIN_PATH, fname)
        if os.path.exists(path):
            vim.command('pyfile ' + path)
            test = Test()
            test.run()
        else:
            OzzyUtils.feedback('test file not found')
    # }}}

# }}}

ozzy = Ozzy()

END

" OzzyCmdlineCompletion ------------------------------------------------- {{{

function! OzzyCmdlineCompletion(seed, cmdline, curpos)
python << END
seed = vim.eval('a:seed').decode('utf-8')

def _matches(seed, func=lambda x: x):
    return [r for r in ozzy.db.all()
            if (r.path.startswith(OzzyUtils.setting('scope'))
                and func(os.path.split(r.path)[1]).startswith(func(seed)))]

if OzzyUtils.setting('ignore_case', fmt=int):
    matches = _matches(seed, func=methodcaller('lower'))
else:
    matches = _matches(seed)

if OzzyUtils.setting('mode') == u'context':
    # sort and group records by distance
    groups = OzzyUtils.sort_by_distance(matches)
    lst = OzzyUtils.sort_groups_by(groups, 'last_access', flatten=True)
    compl = [os.path.split(r.path)[1] for r in lst] # get only filenames

    # move the current buffer name to the end of the list if present
    bufname = vim.current.buffer.name
    if bufname:
        fname = os.path.split(bufname.decode('utf-8'))[1]
        if fname in compl:
            compl.append(compl.pop(compl.index(fname)))
else:
    compl = [os.path.split(r.path)[1] for r in
             sorted(matches, key=attrgetter(u'last_access'),
                    reverse=True)]

vim.command("let g:ozzy_completions = []")
for c in OzzyUtils.remove_dupes(compl):
    vim.eval("add(g:ozzy_completions, '{0}')"
             .format(c.encode('utf-8')))

END
    return g:ozzy_completions
endfunction
" }}}

" functions to get ozzy status ------------------------------------------ {{{
" useful to display the Ozzy status on the status bar

function! OzzyModeFlag()
    if g:ozzy_mode == 'most frequent'
        return g:ozzy_most_frequent_flag
    elseif g:ozzy_mode == 'most recent'
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

function! OzzyScopeFlag()
    if g:ozzy_scope == ''
        return 'global'
    else
        return g:ozzy_scope
    endif
endfunction

" }}}

" autocommands ---------------------------------------------------------- {{{

augroup ozzy_plugin
    au!
    au CursorMoved * python ozzy.insp.insert_line_indicator()
    au BufRead,BufWinEnter * python ozzy.remove_unlisted_buffers()
    au BufReadPost * python ozzy.update_buffer()
    au VimLeave * python ozzy.close()
augroup END

" }}}

" commands -------------------------------------------------------------- {{{

command! OzzyInspect python ozzy.OzzyInspect()
command! -nargs=1 -complete=customlist,OzzyCmdlineCompletion Ozzy python ozzy.OzzyOpen(<q-args>)
command! -nargs=+ OzzyAddDirectory python ozzy.OzzyAddDirectory(<q-args>)

command! -nargs=1 -complete=customlist,OzzyCmdlineCompletion OzzyRemove python ozzy.OzzyRemove(<q-args>)
command! -nargs=? OzzyScope python ozzy.OzzyScope(<q-args>)
command! -nargs=+ OzzyKeepLast python ozzy.OzzyKeepLast(<q-args>)
command! OzzyReset python ozzy.OzzyReset()

command! OzzyToggleMode python ozzy.ToggleMode()
command! OzzyToggleFreeze python ozzy.ToggleFreeze()
command! OzzyToggleExtension python ozzy.ToggleExtension()

if g:ozzy_enable_shortcuts
    command! Oi python ozzy.OzzyInspect()
    command! -nargs=+ Oadd python ozzy.OzzyAddDirectory(<q-args>)
    command! -nargs=1 -complete=customlist,OzzyCmdlineCompletion O python ozzy.OzzyOpen(<q-args>)
    command! -nargs=1 -complete=customlist,OzzyCmdlineCompletion Orm python ozzy.OzzyRemove(<q-args>)
    command! -nargs=? Oscope python ozzy.OzzyScope(<q-args>)
    command! -nargs=+ Okeep python ozzy.OzzyKeepLast(<q-args>)
    command! Orst python ozzy.OzzyReset()
    command! OTmode python ozzy.ToggleMode()
    command! OTfreeze python ozzy.ToggleFreeze()
    command! OText python ozzy.ToggleExtension()
endif

if g:ozzy_debug
    command! OzzyTest python ozzy._test()
endif
" }}}
