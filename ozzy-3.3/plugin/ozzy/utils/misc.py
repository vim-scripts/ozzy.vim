# -*- coding: utf-8 -*-
"""
ozzy.utils.misc
~~~~~~~~~~~~~~~

This module defines various utility functions and some tiny wrappers
around vim functions.
"""

import os
import vim
from itertools import izip


def echom(msg):
    """Display a simple feedback to the user via the command line."""
    vim.command('echom "[ozzy] {0}"'.format(msg.replace('"', '\"')))


def escape_spaces(s):
    """To escape spaces from a string."""
    return s.replace(' ', '\ ')


def to_minutes(td):
    """To return the total minutes of a timedelta object."""
    return td.days * 1440 + td.seconds / 60.0


def to_hours(td):
    """To return the total hours of a timedelta object."""
    return td.days * 24.0 + td.seconds / 3600.0


def cwd():
    """To return the current file directory."""
    if vim.current.buffer.name:
        return os.path.dirname(vim.current.buffer.name)
    else:
        return vim.eval('getcwd()')


def redraw():
    """Little wrapper around the redraw command."""
    vim.command('redraw')


def go_to_win(nr):
    """To go to the window with the given number."""
    vim.command('{0}wincmd w'.format(nr))


def set_buffer(lst):
    """To set the whole content of the current buffer at once."""
    vim.current.buffer[:] = lst


def winnr():
    """To return the current window number."""
    return vim.eval('winnr()')


def find_root(path, root_markers):
    """Find the current project root."""
    if path == os.path.sep:
        return ''
    elif any(m in os.listdir(path) for m in root_markers):
        return path
    else:
        return find_root(os.path.dirname(path), root_markers)


def distance(start, dest):
    """To find the distance (in directory tree levels) between two
    directories."""
    sep = os.path.sep

    if dest.startswith(start):
        # 'dest' is a subdirectory of 'start' so we just count the
        # number of directories between them ('dest' included)
        p = dest.replace(start, '')
        return len(p.split(sep)[1:])

    else:
        # from paths to lists
        start_lst = start.strip(sep).split(sep)
        dest_lst = dest.strip(sep).split(sep)

        for d1, d2 in zip(start_lst, dest_lst):
            if d1 == d2:
                # remove common ancestor
                start_lst.remove(d1)
                dest_lst.remove(d1)
            else:
                break

        return len(start_lst) + len(dest_lst) - 2
