from sqlalchemy import create_engine

DATABASE_URL = "mysql+pymysql://app@localhost/shop"

engine = create_engine(DATABASE_URL, pool_size=5, max_overflow=0)


def connect():
    """Checks a connection out of the pool."""
    return engine.connect()
