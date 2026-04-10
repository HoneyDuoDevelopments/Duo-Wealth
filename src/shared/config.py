# Shared configuration and database connectivity

import os
from pathlib import Path
from dotenv import load_dotenv

# Load .env from project root
_project_root = Path(__file__).resolve().parent.parent.parent
load_dotenv(_project_root / ".env")


def get_db_url(instance: str = "test") -> str:
    """
    Build PostgreSQL connection URL from environment variables.

    Args:
        instance: 'test' or 'prod'
    """
    if instance == "test":
        user = os.environ["POSTGRES_TEST_USER"]
        password = os.environ["POSTGRES_TEST_PASSWORD"]
        db = os.environ["POSTGRES_TEST_DB"]
        port = os.environ.get("POSTGRES_TEST_PORT", "5433")
    elif instance == "prod":
        user = os.environ["POSTGRES_PROD_USER"]
        password = os.environ["POSTGRES_PROD_PASSWORD"]
        db = os.environ["POSTGRES_PROD_DB"]
        port = os.environ.get("POSTGRES_PROD_PORT", "5434")
    else:
        raise ValueError(f"Unknown instance: {instance}. Use 'test' or 'prod'.")

    return f"postgresql://{user}:{password}@localhost:{port}/{db}"
