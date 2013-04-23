# -*- coding: utf-8 -*-
"""
ozzy.db
~~~~~~~

This module defines the class responsible for the low-level
communication with the sqlite database.
"""

import os
import time
import sqlite3
from collections import namedtuple


class DBProxy(object):
    """Database proxy."""

    def __init__(self, path_db):

        self.SCHEMA = """
            CREATE TABLE files_index (
                path string primary key,
                fname string not null,
                frequency integer not null,
                last_access timestamp not null
            );"""

        missing_db = not os.path.exists(path_db)
        self.conn = sqlite3.connect(path_db,
            detect_types=sqlite3.PARSE_DECLTYPES, check_same_thread=False)
        self.Row = namedtuple('Row', "path fname frequency last_access")

        if missing_db:
            self.conn.executescript(self.SCHEMA)
            self.conn.commit()

    def commit(func):
        def f(self, *args, **kwargs):
            func(self, *args, **kwargs)
            self.conn.commit()
        return f

    def __contains__(self, path):
        """Implements the 'in' operator behavior."""
        query = "SELECT * FROM files_index WHERE path=?"
        r = self.conn.execute(query, (u"{0}".format(path.decode('utf-8')),)).fetchone()
        return True if r else False

    def all(self, exclude=None):
        """To get all rows."""
        if exclude:
            exclude = u"{0}".format(exclude.decode('utf-8'))
        query = "SELECT * FROM files_index"
        if exclude:
            query += " WHERE path!=?"
            r = self.conn.execute(query, (exclude,)).fetchall()
        else:
            r = self.conn.execute(query).fetchall()

        for row in r:
            yield self.Row(*row)

    def get(self, target, exclude=None):
        """To get all rows whose 'fname' field contains 'target' ."""
        target = u"%{0}%".format(target)
        if exclude:
            exclude = u"{0}".format(exclude.decode('utf-8'))
        query = "SELECT * FROM files_index WHERE fname LIKE ?"
        if exclude:
            query += " AND path!=?"
            r = self.conn.execute(query, (target, exclude)).fetchall()
        else:
            r = self.conn.execute(query, (target,)).fetchall()

        for row in r:
            yield self.Row(*row)

    @commit
    def add(self, path, last_access):
        """To add a new record."""
        path = u"{0}".format(path.decode('utf-8'))
        try:
            sql = "INSERT INTO files_index VALUES (?, ?, ?, ?)"
            self.conn.execute(sql,
                (path, os.path.split(path)[1], 1, last_access))
        except Exception as e:
            pass

    @commit
    def update(self, path, frequency=None, last_access=None):
        """To update attributes of an existing record."""
        path = u"{0}".format(path.decode('utf-8'))
        if frequency and not last_access:
            sql = ("UPDATE files_index SET "
                   "frequency=frequency+? WHERE path=?")
            self.conn.execute(sql, (frequency, path))

        elif last_access and not frequency:
            sql = "UPDATE files_index SET last_access=? WHERE path=?"
            self.conn.execute(sql, (last_access, path))

        elif frequency and last_access:
            sql = ("UPDATE files_index SET "
                   "frequency=frequency+?, last_access=? WHERE path=?")
            self.conn.execute(sql, (frequency, last_access, path))

    @commit
    def delete_many(self, paths):
        """To delete a bunch of records given their paths."""
        sql = "DELETE FROM files_index WHERE path=?"
        self.conn.executemany(sql, [(u"{0}".format(path),) 
                                    for path in paths])

    @commit
    def delete_all(self):
        """To delete all records from the database."""
        self.conn.execute("DELETE FROM files_index")

    def close(self):
        """To close the database connection."""
        self.conn.close()
