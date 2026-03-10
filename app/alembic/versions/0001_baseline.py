"""baseline

Revision ID: 0001
Revises:
Create Date: 2026-03-09

"""

from alembic import op  # noqa: F401

# revision identifiers, used by Alembic.
revision = "0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Baseline marker — no schema changes.
    # Tables are created at startup via Base.metadata.create_all() until
    # Alembic owns schema lifecycle. Future migrations build on this revision.
    pass


def downgrade() -> None:
    pass
