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
from itertools import izip
from datetime import datetime
import ozzy.utils.misc
import ozzy.db


class Data:

    def __init__(self, db_path):
        self.misc = ozzy.utils.misc
        self.db = ozzy.db.DBProxy(db_path)

    def close(self):
        """To perform some cleanup actions."""
        self.db_maintenance()
        self.db.close()

    def db_maintenance(self):
        """To remove no more existent files from the database."""
        to_delete = (r.path for r in self.db.all()
                     if not os.path.exists(r.path))
        self.db.delete_many(to_delete)

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
        cwd = vim.eval('getcwd()')
        now = datetime.now()
        bytime = {}
        bydist = {}
        byfreq = {}

        matches = list(self.db.get(seed, exclude))
        if matches:
            for r in matches:
                bytime[r.path] = self.misc.to_minutes(now - r.last_access)**2
                bydist[r.path] = self.distance(cwd, r.path)**2
                byfreq[r.path] = 1.0 / sqrt(r.frequency)

            maxtime = max(bytime.values()) * 1.0
            maxdist = max(bydist.values()) * 1.0

            return (((bytime[path] / maxtime + bydist[path] / maxdist
                    + byfreq[path]), path)
                    for path in byfreq)
        else:
            return []
