# -*- coding: utf-8 -*-
"""
ozzy.launcher
~~~~~~~~~~~~~

This module defines the class that implements the launcher.
"""

from __future__ import division

import os
import re
import vim
from math import *

import ozzy.input
import ozzy.utils.misc
import ozzy.utils.settings


class Launcher:

    def __init__(self, plug, data_layer):
        self.settings = ozzy.utils.settings
        self.misc = ozzy.utils.misc

        self.plug = plug
        self.data = data_layer
        self.name = 'ozzy.launcher'
        self.prompt = self.settings.get('prompt')
        self.input_so_far = ''
        self.launcher_win = None
        self.curr_pos = None
        self.curr_entries_number = 0
        self.curr_file = None
        self.curr_win = None
        self.mapper = {}
        self.orig_settings = {}
        self.max_entries = self.settings.get('max_entries', int)
        self.RE_MATH = re.compile('(\d+|\+|\*|\/|-)')

        # setup highlight groups
        self.setup_colors()

    def setup_colors(self):
        """Setups highlight groups according to the current settings."""

        paths = self.settings.get("paths_color")
        matches = self.settings.get("matches_color")
        dirs = self.settings.get("last_dir_color")

        if vim.eval("&background") == 'dark':
            p = self.settings.get("paths_color_darkbg")
            path = p if p else paths
            m = self.settings.get("matches_color_darkbg")
            matches = m if m else matches
            d = self.settings.get("last_dir_color_darkbg")
            dirs = d if d else dirs

        for g, c in (("Paths", paths), ("Matches", matches), ("Dirs", dirs)):
            if "=" not in c:
                # a group is found
                vim.command("hi link Ozzy{0} {1}".format(g, c))
            else:
                vim.command("hi Ozzy{0} {1}".format(g, c))

    def restore_old_settings(self):
        """Restore original settings."""
        specials = ("@/",)
        for sett, val in self.orig_settings.items():
            if sett in specials:
                vim.command("""let {}="{}" """.format(
                    sett, val.replace('"', '\\"')))
            else:
                vim.command('set {0}={1}'.format(sett, val))

    def reset_launcher(self):
        self.input_so_far = ''
        self.launcher_win = None
        self.curr_pos = None
        self.curr_entries_number = 0
        self.curr_file = None
        self.mapper = {}

    def setup_buffer(self):
        """To setup buffer properties of the matches list window."""
        vim.command("setlocal buftype=nofile")
        vim.command("setlocal bufhidden=wipe")
        vim.command("setlocal encoding=utf-8")
        vim.command("setlocal nobuflisted")
        vim.command("setlocal noundofile")
        vim.command("setlocal nobackup")
        vim.command("setlocal noswapfile")
        vim.command("setlocal nowrap")
        vim.command("setlocal nonumber")
        vim.command("setlocal cursorline")
        vim.command("setlocal nolist")
        vim.command("setlocal nospell")
        vim.command("setlocal textwidth=0")
        vim.command('setlocal colorcolumn=0')
        vim.command("try|setlocal norelativenumber|catch|endtry")
        self.orig_settings['@/'] = vim.eval('@/')
        vim.command('let @/ = ""')
        self.orig_settings['laststatus'] = vim.eval('&laststatus')
        vim.command('setlocal laststatus=0')
        self.orig_settings['guicursor'] = vim.eval('&guicursor')
        vim.command("setlocal guicursor=a:hor5-Cursor-blinkwait100")

    def highlight(self, max_len, input):
        vim.command("syntax clear")
        vim.command('syn match OzzyPaths /\%>{0}c./'.format(max_len + 3))
        if input:
            vim.command("syn match OzzyMatches /\%<{0}v\c{1}/".format(
                max_len + 2, input.encode('utf-8', 'ignore')))

    def close_launcher(self):
        """To close the matches list window."""
        self.misc.go_to_win(self.launcher_win)
        self.reset_launcher()
        self.restore_old_settings()
        vim.command('q')
        if self.curr_win:
            self.misc.go_to_win(self.curr_win)

    def open_launcher(self):
        """To open the matches list window."""
        vim.command('silent! botright split {0}'.format(self.name))
        self.setup_buffer()
        return vim.eval("bufwinnr('{0}')".format(self.name))

    def update_launcher(self):
        """To update the matches list content."""
        if not self.launcher_win:
            self.launcher_win = self.open_launcher()

        self.misc.go_to_win(self.launcher_win)
        self.misc.set_buffer(None)

        if self.is_arithmetic_expr(self.input_so_far):

            result = self.eval_arithmetic_expr(self.input_so_far)

            if result:
                res = ' = {0}'.format(result)
            else:
                res = ' = ...'

            vim.command('syntax clear')
            self.misc.set_buffer([res])
            vim.current.window.height = 1
            self.curr_pos = 0

        else:

            scoreboard = self.data.make_scoreboard(
                self.input_so_far, exclude=self.curr_file)
            data = [path for score, path in sorted(scoreboard, reverse=True)]

            if data:

                data = data[-self.max_entries:]
                m = max(len(os.path.basename(path)) for path in data)
                self.mapper = dict(enumerate(data))
                self.misc.set_buffer([self.format_record(p, m) for p in data])
                vim.current.window.height = len(data)
                self.highlight(m, self.input_so_far)
                self.format_curr_line(m)

            else:

                vim.command('syntax clear')
                self.misc.set_buffer([' nothing found...'])
                vim.current.window.height = 1
                self.curr_pos = 0

        if self.curr_pos is not None:
            vim.current.window.cursor = (self.curr_pos + 1, 1)
        self.curr_entries_number = vim.current.window.height

        vim.command("normal! 0")

    def is_arithmetic_expr(self, expr):
        """To detect an arithmetic expression (very naive)."""
        if self.RE_MATH.search(expr):
            return True

    def eval_arithmetic_expr(self, expr):
        """To evaluate an arithmetic expression."""
        try:
            return eval(expr)
        except:
            return None

    def format_record(self, path, max_len):
        """To format a match displayed in the matches list window."""
        path = path.encode('utf-8')
        path = path.replace(os.path.realpath(os.path.expanduser('~')), '~')

        if self.settings.get("show_file_names", bool):
            full_path = path
        else:
            full_path = os.path.dirname(path)

        return '  {0: <{1}}{2}'.format(
            os.path.basename(path), max_len + 4, full_path)

    def format_curr_line(self, max_len):
        """To format the current line in the laucher window."""
        if self.curr_pos is None:
            self.curr_pos = len(vim.current.buffer) - 1
        line = vim.current.buffer[self.curr_pos]
        vim.current.buffer[self.curr_pos] = '▸ ' + line[2:]

    def open_selected_file(self):
        """To open the file on the selected line."""
        path = self.mapper.get(self.curr_pos)
        self.close_launcher()
        vim.command('sil! e {0}'.format(self.misc.escape_spaces(path)))

    def delete_selected_file(self):
        """To delete the selected file from the database."""
        path = self.mapper.get(self.curr_pos)
        if path.startswith('~'):
            path = os.path.join(os.path.expanduser('~'), path[2:])

        self.data.delete_file(path)

    def open(self):
        """To open the launcher."""
        # Remember the currently open file so that we can exclude it
        # from the matches
        self.curr_file = vim.current.buffer.name
        self.curr_win = self.misc.winnr()

        # This first call opens the list of matches even though the user
        # didn't give any character as input
        self.update_launcher()
        self.misc.redraw()

        input = ozzy.input.Input()
        # Start the input loop
        while True:

            if self.plug.mode:
                mode = self.settings.get('project_mode_flag')
            else:
                mode = self.settings.get('global_mode_flag')

            # Display the prompt and the text the user has been typed so far
            prompt = """{0}{1}{2}""".format(
                mode, self.prompt, self.input_so_far.encode('utf-8'))
            prompt = prompt.replace("\\", "\\\\").replace('"', '\\"')
            vim.command("echo \"{0}\"".format(prompt))

            # Get the next character
            input.get()

            if (input.RETURN or input.CTRL and input.CHAR == 'o'
                or input.CTRL and input.CHAR == 'e'):
                # The user have chosen the currently selected match
                self.open_selected_file()
                self.data.cache = []
                break

            elif input.BS:
                # This acts just like the normal backspace key
                self.input_so_far = u"{0}".format(self.input_so_far)[:-1]
                # Reset the position of the selection in the matches list
                # because the list has to be rebuilt
                self.curr_pos = None
                self.data.cache = []

            elif input.ESC or input.INTERRUPT:
                # The user want to close the launcher
                self.close_launcher()
                self.data.cache = []
                self.misc.redraw()
                break

            elif input.UP or input.TAB or input.CTRL and input.CHAR == 'k':
                # Move up in the matches list
                last_index = len(vim.current.buffer) - 1
                if self.curr_pos == 0:
                    self.curr_pos = last_index
                else:
                    self.curr_pos -= 1

            elif input.DOWN or input.CTRL and input.CHAR == 'j':
                # Move down in the matches list
                last_index = len(vim.current.buffer) - 1
                if self.curr_pos == last_index:
                    self.curr_pos = 0
                else:
                    self.curr_pos += 1

            elif input.CTRL and input.CHAR == 'd':
                self.delete_selected_file()
                self.curr_pos = None
                self.data.cache = []

            elif input.CTRL and input.CHAR == 'u':
                # clear the current search
                self.input_so_far = ''
                self.curr_pos = None
                self.data.cache = []

            elif input.CHAR:
                # A printable character has been pressed. We have to remember
                # it so that in the next loop we can display exactly what the
                # user has been typed so far
                self.input_so_far += input.CHAR.decode('utf-8')

                # Reset the position of the selection in the matches list
                # because the list has to be rebuilt
                self.curr_pos = None

            else:
                self.misc.redraw()
                continue

            self.update_launcher()

            # Clean the command line
            self.misc.redraw()
