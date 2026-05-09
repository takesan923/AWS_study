from alembic import op
import sqlalchemy as sa

revision = '0001'
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'tasks',
        sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column('title', sa.String(255), nullable=False),
        sa.Column('description', sa.String(1000), nullable=True),
        sa.Column('status', sa.Enum('pending', 'in_progress', 'done'),
                nullable=False, server_default='pending'),
        sa.Column('created_at', sa.DateTime(timezone=True),
                server_default=sa.text('NOW()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True),
                server_default=sa.text('NOW()'), nullable=False),
    )


def downgrade():
    op.drop_table('tasks')