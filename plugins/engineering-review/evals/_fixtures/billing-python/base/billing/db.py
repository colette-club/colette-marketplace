from contextlib import contextmanager

from app.database import connection


@contextmanager
def transaction():
    """Runs the block in one database transaction; rolls back on any exception."""
    with connection.begin():
        yield connection
