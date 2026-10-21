from contextlib import contextmanager

from app.database import connect


@contextmanager
def transaction():
    """Runs the block in one database transaction on its own connection; rolls back on any exception."""
    with connect() as connection, connection.begin():
        yield connection
