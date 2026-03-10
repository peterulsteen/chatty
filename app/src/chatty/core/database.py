"""
Database configuration and session management.
"""

import uuid
from datetime import UTC, datetime
from typing import Generator

from sqlalchemy import Column, DateTime, String, create_engine
from sqlalchemy.orm import Session, declarative_base, sessionmaker

from chatty.config import settings

SQLALCHEMY_DATABASE_URL = settings.DATABASE_URL

# SQLite requires check_same_thread=False; Postgres does not accept this arg
_connect_args = {"check_same_thread": False} if SQLALCHEMY_DATABASE_URL.startswith("sqlite") else {}

# Create SQLAlchemy engine
engine = create_engine(SQLALCHEMY_DATABASE_URL, connect_args=_connect_args)

# Create SessionLocal class
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Create Base class for models
Base = declarative_base()


# TODO - Probs best to move to models folder
class BaseModel(Base):
    """Base model with common fields."""

    __abstract__ = True

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    created_date = Column(DateTime, default=lambda: datetime.now(UTC), nullable=False)
    last_updated_date = Column(
        DateTime,
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
        nullable=False,
    )


def get_db() -> Generator[Session, None, None]:
    """
    Dependency to get database session.

    Yields:
        Session: SQLAlchemy database session
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def create_tables() -> None:
    """Create all database tables."""
    Base.metadata.create_all(bind=engine)
