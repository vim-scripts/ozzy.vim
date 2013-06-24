# -*- coding: utf-8 -*-
"""
ozzy.db
~~~~~~~

This module defines the class responsible for the high-level operations
on the database such as data retrieval, data updates and data removal.
"""

from __future__ import division

import os
import vim
import json
from math import sqrt
from datetime import datetime
from itertools import ifilter
from collections import OrderedDict

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

    def make_scoreboard(self, seed, exclude=None):
        """To compute the score for each match, the lower the better."""
        cwd = self.misc.cwd()
        now = datetime.now()
        bytime = {}; bydist = {}; byfreq = {}; bypos = {}

        matches = self.db.get(seed, exclude)

        if self.plug.mode:
            root = self.misc.find_root(cwd, self.settings.get('root_markers'))
            if root:
                matches = ifilter(lambda r: r.path.startswith(root), matches)

        if not self.settings.get("ignore_case", bool):
            matches = (m for m in matches if seed in m.fname)

        for r in matches:

            # delete the file from the database if it does not exist
            if not os.path.exists(r.path):
                self.delete_file(r.path)
                continue

            bytime[r.path] = sqrt(self.misc.to_minutes(now - r.last_access))
            bydist[r.path] = self.misc.distance(cwd, r.path)**2 + 1
            byfreq[r.path] = sqrt(r.frequency)
            bypos[r.path] = os.path.basename(r.path).lower().index(seed.lower()) + 1

        if bytime:

            maxtime = max(bytime.values())
            maxdist = max(bydist.values())
            maxfreq = max(byfreq.values())
            maxpos = max(bypos.values())

            for path in bytime:
                freq_norm = 1 - byfreq[path] / maxfreq
                time_norm = (bytime[path] / maxtime)**0.4
                dist_norm = (bydist[path] / maxdist)**0.4
                pos_norm = bypos[path] / maxpos
                yield (freq_norm + time_norm + dist_norm + pos_norm, path)

        else:
            return

    def _make_rich_scoreboard(self, seed, exclude=None):
        """Make a scoreboard plenty of information. For debug only."""
        cwd = self.misc.cwd()
        now = datetime.now()
        bytime = {}; bydist = {}; byfreq = {}; bypos = {}

        matches = list(self.db.get(seed, exclude))

        root = self.misc.find_root(cwd, self.settings.get('root_markers'))
        if self.plug.mode and root:
            matches = ifilter(lambda r: r.path.startswith(root), matches)

        if not self.settings.get("ignore_case", bool):
            matches = (m for m in matches if seed in m.fname)

        for r in matches:

            # delete the file from the database if it does not exist
            if not os.path.exists(r.path):
                self.delete_file(r.path)
                continue

            bytime[r.path] = sqrt(self.misc.to_minutes(now - r.last_access))
            bydist[r.path] = self.misc.distance(cwd, r.path)**2 + 1
            byfreq[r.path] = sqrt(r.frequency)
            bypos[r.path] = os.path.basename(r.path).lower().index(seed.lower()) + 1

        if bytime:

            maxtime = max(bytime.values())
            maxdist = max(bydist.values())
            maxfreq = max(byfreq.values())
            maxpos = max(bypos.values())

            results = dict()

            for r in matches:

                if r.path in bytime:

                    freq_score = 1 - byfreq[r.path] / maxfreq
                    time_score = (bytime[r.path] / maxtime)**0.4
                    dist_score = (bydist[r.path] / maxdist)**0.4
                    pos_score = bypos[r.path] / maxpos

                    d = OrderedDict()
                    d['score'] = freq_score + time_score + dist_score + pos_score
                    d['freq'] = sqrt(r.frequency)
                    d['freq_score'] = freq_score
                    d['timedelta'] = bytime[r.path]
                    d['timedelta_score'] = time_score
                    d['dist'] = bydist[r.path]
                    d['dist_score'] = dist_score
                    d['seedpos'] = bypos[r.path]
                    d['seedpos_score'] = pos_score
                    results[r.path] = d

            return OrderedDict(
                sorted([(path, d) for path, d in results.items()],
                       key=lambda t: t[1]['score']))
        else:
            return {}

    def print_scoreboard(self, seed='', indent=2):
        """Print the scoreboard. For debug only."""
        print json.dumps(self.make_rich_scoreboard(seed), indent=indent)
