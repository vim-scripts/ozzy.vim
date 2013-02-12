# -*- coding: utf-8 -*-
"""
ozzy.utils.misc
~~~~~~~~~~~~~~~

This module defines various utility functions and some tiny wrappers
around vim functions.
"""

import vim


def echom(msg):
    """Display a simple feedback to the user via the command line."""
    vim.command('echom "[ozzy] {0}"'.format(msg.replace('"', '\"')))


def echoerr(msg):
    """Display a simple error feedback to the user via the command line."""
    vim.command('echohl WarningMsg|echom "[ozzy] {0}"|echohl None'.format(
        msg.replace('"', '\"')))


def escape_spaces(s):
    """To escape spaces from a string."""
    return s.replace(' ', '\ ')


def to_minutes(td):
    """To return the total minutes of a timedelta object."""
    return td.days * 1440 + td.seconds / 60.0


def cwd():
    """To return the current vim cwd."""
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
