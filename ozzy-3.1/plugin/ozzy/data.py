# -*- coding: utf-8 -*-
"""
ozzy.db
~~~~~~~

This module defines the class responsible for the high-level operations
on the database such as data retrieval, data updates and data removal.
"""

import os
import vim
from math import sqrt
from datetime import datetime
from itertools import izip, ifilter

import ozzy.db
import ozzy.utils.misc
import ozzy.utils.settings


class Data:

    def __init__(self, plug, db_path):
        # modules reference shortcuts
        self.settings = ozzy.utils.settings
        self.misc = ozzy.utils.misc

        self.plug = plug
        self.db = ozzy.db.DBProxy(db_path)

    def close(self):
        """To perform some cleanup actions."""
        self.db.close()

    def update_file(self, bufname):
        """To add or update the given file."""
        now = datetime.now()
        if bufname in self.db:
            self.db.update(bufname, +1, now)
        else:
            self.db.add(bufname, now)

    def delete_file(self, path):
        """To remove the given file from the database."""
        self.db.delete_many([path])

    def clear_index(self):
        self.db.delete_all()

    def distance(self, start, dest):
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

            for d1, d2 in izip(start_lst, dest_lst):
                if d1 == d2:
                    # remove common ancestor
                    start_lst.remove(d1)
                    dest_lst.remove(d1)
                else:
                    break

            return len(start_lst) + len(dest_lst) - 2

    def make_scoreboard(self, seed, exclude=None):
        """To compute the score for each match, the lower the better."""
        cwd = self.misc.curr_file_dir()
        now = datetime.now()
        bytime = {}; bydist = {}; byfreq = {}

        matches = self.db.get(seed, exclude)

        root = self.misc.find_root(cwd, self.settings.get('root_markers'))
        if self.plug.mode and root:
            matches = ifilter(lambda r: r.path.startswith(root), matches)

        for r in matches:

            # delete the file from the database if it does not exist
            if not os.path.exists(r.path):
                self.delete_file(r.path)
                continue

            bytime[r.path] = self.misc.to_minutes(now - r.last_access)**2
            bydist[r.path] = self.distance(cwd, r.path)**2
            byfreq[r.path] = 1.0 / sqrt(r.frequency)

        if bytime:

            maxtime = max(bytime.values()) * 1.0
            maxdist = max(bydist.values()) * 1.0
            return (((bytime[path] / maxtime + bydist[path] / maxdist
                    + byfreq[path]), path)
                    for path in bytime)
        else:
            return []
