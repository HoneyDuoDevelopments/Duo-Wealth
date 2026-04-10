"""
Smoke test: verify PostgreSQL test instance is running and accessible.

Run with: pytest tests/ -v
Or directly: python tests/test_db_connection.py
"""

import psycopg
import pytest
from src.shared.config import get_db_url


def test_connection():
    """Can we connect to the test database?"""
    url = get_db_url("test")
    with psycopg.connect(url) as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT 1")
            result = cur.fetchone()
            assert result == (1,)


def test_create_and_query():
    """Can we create a table, insert, and query?"""
    url = get_db_url("test")
    with psycopg.connect(url) as conn:
        with conn.cursor() as cur:
            # Clean up from any previous run
            cur.execute("DROP TABLE IF EXISTS _smoke_test")

            # Create
            cur.execute("""
                CREATE TABLE _smoke_test (
                    id SERIAL PRIMARY KEY,
                    message TEXT NOT NULL,
                    created_at TIMESTAMPTZ DEFAULT NOW()
                )
            """)

            # Insert
            cur.execute(
                "INSERT INTO _smoke_test (message) VALUES (%s) RETURNING id",
                ("Duo Wealth data layer is alive",),
            )
            row_id = cur.fetchone()[0]
            assert row_id == 1

            # Query
            cur.execute("SELECT message FROM _smoke_test WHERE id = %s", (row_id,))
            result = cur.fetchone()
            assert result[0] == "Duo Wealth data layer is alive"

            # Clean up
            cur.execute("DROP TABLE _smoke_test")

        conn.commit()


def test_version():
    """Verify we're on PostgreSQL 16."""
    url = get_db_url("test")
    with psycopg.connect(url) as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT version()")
            version = cur.fetchone()[0]
            assert "PostgreSQL 16" in version


if __name__ == "__main__":
    print("Testing database connection...")
    test_connection()
    print("✅ Connection OK")

    test_create_and_query()
    print("✅ Create/Insert/Query OK")

    test_version()
    print("✅ PostgreSQL 16 confirmed")

    print("\nAll smoke tests passed.")
