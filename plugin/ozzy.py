# -*- coding: utf-8 -*-
"""
ozzy.py
~~~~~~~

This module defines the main Ozzy class.
"""

import os
import vim
import sys

sys.path.insert(0, os.path.split(
    vim.eval('fnameescape(globpath(&runtimepath, "plugin/ozzy.py"))'))[0])

import ozzy.data
import ozzy.launcher
import ozzy.utils.settings
import ozzy.utils.misc


class Ozzy(object):
    """Main ozzy class."""

    def __init__(self):
        # modules reference shortcuts
        self.settings = ozzy.utils.settings
        self.misc = ozzy.utils.misc

        # set the path for the application data location
        self.data_path = self.data_path()
        if not self.data_path:
            self.misc.echom('The platform you are running is not supported')
            return
        try:
            if not os.path.exists(self.data_path):
                os.mkdir(self.data_path)
        except IOError:
            self.misc.echoerr('Ozzy cannot create its database '
                              'under {0}'.format(self.data_path))

        self.data = ozzy.data.Data(self.data_path + '/index.db')
        self.launcher = ozzy.launcher.Launcher(self.data)

    def data_path(self):
        """To set the path for the application data location."""
        if sys.platform == 'darwin':
            return (os.path.expanduser('~') +
                    '/Library/Application Support/Ozzy')
        elif sys.platform == 'linux2':
            return os.path.expanduser('~') + '/.ozzy'

    def should_ignore(self, bufname):
        """To ingnore some type of files."""
        fname = os.path.split(bufname)[1]
        for patt in self.settings.get('ignore'):

            if patt.startswith('*.'):
                if fname.endswith(patt[1:]):
                    return True

            elif patt.endswith('.*'):
                if fname.startswith(patt[:-2]):
                    return True

            elif patt.endswith(os.path.sep):
                if patt in bufname:
                    return True

            elif fname == patt:
                return True

        return False

    def update_buffer(self):
        """To update the attributes of the opened buffer."""
        buf = vim.current.buffer.name
        if buf and os.path.exists(buf):

            if vim.eval("exists('b:ozzy_buffer_flag')") == '0':

                onlyin = self.settings.get('track_only')
                if not onlyin or any(buf.startswith(d) for d in onlyin):

                    if not self.should_ignore(buf):
                        vim.command("let b:ozzy_buffer_flag = 1")
                        self.data.update_file(buf)

    def close(self):
        """To perform some cleanup actions."""
        self.data.close()

    def Open(self):
        """To open the launcher."""
        self.launcher.open()

    def Reset(self):
        """To clear the entire database."""
        answer = vim.eval("input('Are you sure? (yN): ')")
        vim.command('redraw')
        if answer in ['y', 'Y', 'yes', 'Yes', 'sure']:
            self.data.clear_index()
            self.misc.echom('reset successful!')
