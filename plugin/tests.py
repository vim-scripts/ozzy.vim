# -*- coding: utf-8 -*-
"""
tests.py

This script file depends on functionalities provided by Ozzy plugin and should
be executed only via the OzzyTest command. To enable OzzyTest command set to
1 the g:ozzy_debug variable in your .vimrc or in the ozzy.vim file.
"""

class Test(object):

    def __init__(self):
        self.name = 'ozzy_test'
        self.cwd = os.getcwd()
        self.settings = {} # to save and restore original settings
        self.Row = namedtuple('Row', "path frequency last_access")

        self.func_utils = (
            'test__escape_spaces',
            'test__listed_buffers',
            'test__remove_dupes',
            'test__is_sublist',
            'test__seconds',
            'test__setting',
            'test__let',
            'test__match_patterns',
            'test__find_by_path',
            'test__find_by_fname',
            'test__find_paths_in_directory',
            #'test__find_project_root',
            'test__decorate_with_distance',
            'test__sort_by_distance',
            'test__sort_groups_by',
            'test__group_by_path',
            'test__decorate_groups_mean',
            'test__get_cmdline_opt',
        )

    def run(self):
        """Opens the test buffer."""
        vim.command("e {0}".format(self.name))
        vim.command("let b:ozzy_test_buffer_opened=1")
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

    def render(self): 
        """Renders the test buffer content."""
        b = vim.current.buffer
        b.append(' >> Ozzy tests (press ''q'' to quit)')
        b.append('')

        b.append(' Tests for: Utils class')
        b.append(' ----------------------------------------')
        for f in self.func_utils:
            callf = getattr(self, f)
            r = callf()
            b.append(' {0:.<35} {1}'.format(f + ' ', 'OK' if r else 'FAIL'))

    def map_keys(self):
        """Creates mappings for the test buffer."""
        mappings = (
            'q :bd',
        )

        for m in mappings:
            vim.command('nnoremap <buffer> <silent> ' + m + '<CR>')

    def comm(self, command):
        vim.command('silent ' + command)

    # Utils class tests
    # -----------------------------------------------------

    def test__escape_spaces(self):
        s = 'hello world!'
        cond1 = Utils.escape_spaces(s) == 'hello\ world!'
        cond2 = Utils.escape_spaces('') == ''
        return cond1 and cond2

    def test__listed_buffers(self):
        self.comm('badd test_buffer')
        buflist1 = Utils.listed_buffers()
        cond1 = os.path.join(self.cwd, 'test_buffer') in buflist1
        self.comm('bdelete test_buffer')
        buflist2 = Utils.listed_buffers()
        cond2 = os.path.join(self.cwd, 'test_buffer') not in buflist2
        return cond1 and cond2

    def test__remove_dupes(self):
        l1 = Utils.remove_dupes([1,2,3,1,2,5,8,3])
        l2 = Utils.remove_dupes([1,1,1,1])
        l3 = Utils.remove_dupes([])
        return l1 == [1,2,3,5,8] and l2 == [1] and l3 == []

    def test__is_sublist(self):
        l = [1,3,4,7,8,1,2]
        cond1 = Utils.is_sublist([4,7,8], l)
        cond2 = Utils.is_sublist([4], l)
        cond3 = Utils.is_sublist([], l)
        cond4 = not Utils.is_sublist([1,2,3], l)
        cond5 = not Utils.is_sublist([0,1,3], l)
        return cond1 and cond2 and cond3 and cond4 and cond5 

    def test__seconds(self):
        td1 = datetime.timedelta(seconds=50, days=0)
        td2 = datetime.timedelta(seconds=50, days=1)
        cond1 = Utils.seconds(td1) == 50
        cond2 = Utils.seconds(td2) == 50 + 1 * 24 * 3600
        return cond1 and cond2

    def test__setting(self):
        name = 'test_variable'

        self.comm('let g:ozzy_{0} = 1'.format(name))
        c1 = Utils.setting(name, fmt=int) == 1
        self.comm('unlet g:ozzy_{0}'.format(name))

        self.comm('let g:ozzy_{0} = 1'.format(name))
        c2 = Utils.setting(name, fmt=bool) is True
        self.comm('unlet g:ozzy_{0}'.format(name))

        self.comm('let g:ozzy_{0} = "hello"'.format(name))
        c3 = Utils.setting(name) == "hello"
        self.comm('unlet g:ozzy_{0}'.format(name))

        self.comm('let g:ozzy_{0} = []'.format(name))
        c4 = Utils.setting(name) == []
        self.comm('unlet g:ozzy_{0}'.format(name))

        self.comm('let g:ozzy_{0} = "abcd"'.format(name))
        c4 = Utils.setting(name, fmt=len) == 4
        self.comm('unlet g:ozzy_{0}'.format(name)) 

        #try:
            #c5 = Utils.setting('non_existent_var')
            #c5 = False
        #except vim.error:
            #c5 = True

        return all([c1, c2, c3, c4])   

    def test__let(self):
        name = 'test_variable'
        c1 = c2 = c3 = c4 = False

        Utils.let(name, 'test')
        if vim.eval('exists("g:ozzy_{0}")'.format(name)) == '1':
            if vim.eval('g:ozzy_{0}'.format(name)) == 'test':
                c1 = True
            self.comm('unlet g:ozzy_{0}'.format(name))

        Utils.let(name, True)
        if vim.eval('exists("g:ozzy_{0}")'.format(name)) == '1':
            if int(vim.eval('g:ozzy_{0}'.format(name))) == 1:
                c2 = True
            self.comm('unlet g:ozzy_{0}'.format(name))

        Utils.let(name, 1)
        if vim.eval('exists("g:ozzy_{0}")'.format(name)) == '1':
            if int(vim.eval('g:ozzy_{0}'.format(name))) == 1:
                c3 = True  
            self.comm('unlet g:ozzy_{0}'.format(name))

        Utils.let(name, [])
        if vim.eval('exists("g:ozzy_{0}")'.format(name)) == '1':
            if vim.eval('g:ozzy_{0}'.format(name)) == []:
                c4 = True
            self.comm('unlet g:ozzy_{0}'.format(name))

        return all([c1, c2, c3, c4])

    def test__match_patterns(self):
        c1 = Utils.match_patterns('hello', ['hello'])
        c2 = not Utils.match_patterns('hello', ['hell'])

        c3 = Utils.match_patterns('hello.txt', ['*.txt'])
        c4 = not Utils.match_patterns('hello', ['*.txt'])

        c5 = Utils.match_patterns('hello.txt', ['hello.*'])
        c6 = Utils.match_patterns('hello', ['hello.*'])

        c7 = Utils.match_patterns('/hello/file', ['hello/'])
        c8 = not Utils.match_patterns('/hello-world/file', ['hello/'])
        c9 = not Utils.match_patterns('/world-hello/file', ['hello/'])
        c10 = not Utils.match_patterns('/hello/file', ['world/hello/'])

        return all([c1, c2, c3, c4, c5, c6, c7, c8, c9, c10])

    def test__find_by_path(self):
        a = self.Row('a/f.txt', 1, None)
        b = self.Row('a/f.py', 1, None) 
        c = self.Row('a/g/h.vim', 1, None)
        d = self.Row('a/c/b/g/H.vim', 1, None) 
        records = [a, b, c, d]

        # save current settings
        self.settings['ignore_case'] = Utils.setting('ignore_case')
        self.settings['ignore_ext'] = Utils.setting('ignore_ext')
        self.settings['scope'] = Utils.setting('scope')
        Utils.let('scope', '')
        Utils.let('ignore_case', 0)
        Utils.let('ignore_ext', 0)

        c1 = list(Utils.find_by_path(records, 'a/f')) == []
        c2 = list(Utils.find_by_path(records, 'a/f.txt')) == [a]
        c3 = list(Utils.find_by_path(records, 'a/F.txt')) == []
        Utils.let('ignore_case', 1)
        c1 = list(Utils.find_by_path(records, 'a/F')) == []
        c4 = list(Utils.find_by_path(records, 'a/f.txt')) == [a]
        c5 = list(Utils.find_by_path(records, 'a/F.txt')) == [a]
        Utils.let('ignore_case', 0)

        Utils.let('ignore_ext', 1)
        c6 = list(Utils.find_by_path(records, 'a/f')) == [a, b]
        c7 = list(Utils.find_by_path(records, 'a/F')) == []
        Utils.let('ignore_case', 1)
        c8 = list(Utils.find_by_path(records, 'a/f')) == [a, b]
        c9 = list(Utils.find_by_path(records, 'a/F')) == [a, b]
        Utils.let('ignore_ext', 0)
        Utils.let('ignore_case', 0)

        c10 = list(Utils.find_by_path(records, 'g/h.vim')) == [c]
        Utils.let('ignore_ext', 1)
        c11 = list(Utils.find_by_path(records, 'g/h.vim')) == [c]
        c12 = list(Utils.find_by_path(records, 'g/h')) == [c]
        Utils.let('ignore_ext', 0)

        Utils.let('ignore_case', 1)
        c13 = list(Utils.find_by_path(records, 'g/H.vim')) == [c, d]
        c14 = list(Utils.find_by_path(records, 'g/h.vim')) == [c, d]

        # restore previous settings
        Utils.let('ignore_case', self.settings['ignore_case'])
        Utils.let('ignore_ext', self.settings['ignore_ext'])
        Utils.let('scope', self.settings['scope'])
        return all([c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, c13,
                   c14]) 

    def test__find_by_fname(self):
        a = self.Row('a/f.txt', 1, None)
        b = self.Row('a/c/f.py', 1, None) 
        c = self.Row('a/b/h.vim', 1, None)
        d = self.Row('a/c/b/h/H.vim', 1, None) 
        records = [a, b, c, d]

        # save current settings
        self.settings['ignore_case'] = Utils.setting('ignore_case')
        self.settings['ignore_ext'] = Utils.setting('ignore_ext')
        self.settings['scope'] = Utils.setting('scope')
        Utils.let('scope', '')
        Utils.let('ignore_case', 0)
        Utils.let('ignore_ext', 0)

        c1 = list(Utils.find_by_fname(records, 'f')) == []
        c2 = list(Utils.find_by_fname(records, 'f.txt')) == [a]
        c3 = list(Utils.find_by_fname(records, 'F.txt')) == []
        Utils.let('ignore_case', 1)
        c1 = list(Utils.find_by_fname(records, 'F')) == []
        c4 = list(Utils.find_by_fname(records, 'f.txt')) == [a]
        c5 = list(Utils.find_by_fname(records, 'F.txt')) == [a]
        Utils.let('ignore_case', 0)

        Utils.let('ignore_ext', 1)
        c6 = list(Utils.find_by_fname(records, 'f')) == [a, b]
        c7 = list(Utils.find_by_fname(records, 'F')) == []
        Utils.let('ignore_case', 1)
        c8 = list(Utils.find_by_fname(records, 'f')) == [a, b]
        c9 = list(Utils.find_by_fname(records, 'F')) == [a, b]
        Utils.let('ignore_ext', 0)
        Utils.let('ignore_case', 0)

        c10 = list(Utils.find_by_fname(records, 'h.vim')) == [c]
        Utils.let('ignore_ext', 1)
        c11 = list(Utils.find_by_fname(records, 'h.vim')) == [c]
        c12 = list(Utils.find_by_fname(records, 'h')) == [c]
        Utils.let('ignore_ext', 0)

        Utils.let('ignore_case', 1)
        c13 = list(Utils.find_by_fname(records, 'h.vim')) == [c, d]
        c14 = list(Utils.find_by_fname(records, 'H.vim')) == [c, d]

        # restore previous settings
        Utils.let('ignore_case', self.settings['ignore_case'])
        Utils.let('ignore_ext', self.settings['ignore_ext'])
        Utils.let('scope', self.settings['scope'])
        return all([c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, c13, 
                   c14]) 
     
    def test__find_paths_in_directory(self):
        a = self.Row('a/f', 1, None)
        b = self.Row('a/c/b', 1, None) 
        c = self.Row('a/b/c', 1, None)
        d = self.Row('a/c/b/h', 1, None) 
        records = [a, b, c, d]

        self.settings['scope'] = Utils.setting('scope')

        Utils.let('scope', '')
        c1 = Utils.find_paths_in_directory(records, 'b') == [b, c, d]
        c2 = Utils.find_paths_in_directory(records, 'a') == records
        c3 = Utils.find_paths_in_directory(records, 'c/b') == [b, d]
        c4 = Utils.find_paths_in_directory(records, 'z') == []
        c5 = Utils.find_paths_in_directory([], 'b') == []

        Utils.let('scope', 'a/c')
        c6 = Utils.find_paths_in_directory(records, 'f') == []
        c7 = Utils.find_paths_in_directory(records, 'b') == [b, d]

        Utils.let('scope', self.settings['scope'])
        return all([c1, c2, c3, c4, c5, c6, c7])

    #def test__find_project_root(self):
        #pass

    def test__decorate_with_distance(self):
        a = self.Row('a/f/file', 1, None)
        b = self.Row('a/f/c/file', 1, None) 
        c = self.Row('a/f/c/i/file', 1, None) 
        d = self.Row('a/b/h/file', 1, None)
        records = [a, b, c, d]

        r1 = list(Utils.decorate_with_distance(records, cwd='a/f/c'))
        c1 = r1 == [(1, a), (0, b), (1, c), (4, d)]

        r2 = list(Utils.decorate_with_distance(records, cwd='a/b/h'))
        c2 = r2 == [(3, a), (4, b), (5, c), (0, d)]

        r3 = list(Utils.decorate_with_distance(records, cwd='a'))
        c3 = r3 == [(1, a), (2, b), (3, c), (2, d)]    
        
        return all([c1, c2, c3])

    def test__sort_by_distance(self):
        a = self.Row('a/f/file', 1, None)
        b = self.Row('a/f/c/file', 1, None) 
        c = self.Row('a/f/c/i/file', 1, None) 
        d = self.Row('a/b/h/file', 1, None)
        records = [a, b, c, d]      

        r1 = Utils.sort_by_distance(records, cwd='a/f/c')
        c1 = r1 == [[b], [a, c], [d]]

        r2 = Utils.sort_by_distance(records, cwd='a/b/h') 
        c2 = r2 == [[d], [a], [b], [c]]

        r3 = Utils.sort_by_distance(records, cwd='a')
        c3 = r3 == [[a], [b, d], [c]]

        r4 = Utils.sort_by_distance(records, cwd='a', reverse=True)
        c4 = r4 == [[c], [b, d], [a]]

        return all([c1, c2, c3, c4])

    def test__sort_groups_by(self):
        now = dt.now()
        delta = datetime.timedelta

        a = self.Row('a/b/c', 3, now - delta(seconds=20))
        b = self.Row('a/b', 1, now + delta(seconds=10))
        c = self.Row('a/c/b', 5, now) 
        d = self.Row('a/c/b/h', 2, now + delta(days=1))

        groups = [[a, b], [c, d]]

        # note that 'reverse' is True by default

        r1 = Utils.sort_groups_by(groups, 'path')
        c1 = r1 == [[a, b], [d, c]]

        r2 = Utils.sort_groups_by(groups, 'frequency')
        c2 = r2 == [[a, b], [c, d]]

        r3 = Utils.sort_groups_by(groups, 'last_access')
        c3 = r3 == [[b, a], [d, c]]

        r4 = Utils.sort_groups_by(groups, 'path', reverse=False)
        c4 = r4 == [[b, a], [c, d]]

        r5 = Utils.sort_groups_by(groups, 'path', flatten=True)
        c5 = r5 == [a, b, d, c]

        c6 = Utils.sort_groups_by([], 'path') == []
        c7 = Utils.sort_groups_by([], 'path', flatten=True) == []
        c8 = Utils.sort_groups_by([[], []], 'path') == [[], []]
        c9 = Utils.sort_groups_by([[], []], 'path', flatten=True) == []

        return all([c1, c2, c3, c4, c5, c6, c7, c8, c9]) 

    def test__group_by_path(self):
        a = self.Row('a/b', 1, None)
        b = self.Row('a/c/b', 1, None) 
        c = self.Row('a/b/c', 1, None)
        d = self.Row('a/c/b/h', 1, None)
        l = [a, b, c, d]

        r1 = Utils.group_by_path(l, 'b')
        c1 = r1 == [[a, c], [b, d]]

        r2 = Utils.group_by_path(l, 'a')
        c2 = r2 == [[a, c, b, d]]

        r3 = Utils.group_by_path(l, '')
        c3 = r3 == r2

        try:
            r4 = Utils.group_by_path(l, 'f')
            c4 = False
        except ValueError: # substring not found
            c4 = True
        return all([c1, c2, c3, c4])

    def test__decorate_groups_mean(self):
        now = dt.now()
        delta = datetime.timedelta
        g1 = (self.Row('a/b', 1, now - delta(seconds=5)),
              self.Row('a/b', 1, now - delta(seconds=15)))
        g2 = (self.Row('a/c', 1, now - delta(seconds=0)),
              self.Row('a/c', 1, now - delta(seconds=10)))
        groups = [g1, g2]
        l = Utils.decorate_groups_mean(groups, now)
        return l == [(10.0, g1), (5.0, g2)]

    def test__get_cmdline_opt(self):
        c1 = Utils.get_cmdline_opt('-o', ['-o', 'arg'], expect_arg=True) == 'arg'
        c2 = Utils.get_cmdline_opt('-o', ['-o', 'arg'], expect_arg=False)
        c3 = Utils.get_cmdline_opt('-o', ['-o'], expect_arg=False)
        c4 = not Utils.get_cmdline_opt('-o', ['-o'], expect_arg=True)
        c5 = not Utils.get_cmdline_opt('-o', [], expect_arg=True)
        c6 = not Utils.get_cmdline_opt('-o', [], expect_arg=False)
        return all([c1, c2, c3, c4, c5, c6])
