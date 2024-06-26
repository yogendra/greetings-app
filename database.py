import os
import psycopg2

def get_db_connection():
    conn = psycopg2.connect(
        dbname=os.environ.get("PGDATABASE", "postgres"),
        user=os.environ.get("POSTGRES_USER", "postgres"),
        password=os.environ.get("POSTGRES_PASSWORD", "postgres"),
        host=os.environ.get("POSTGRES_HOST", "localhost"),
        port=os.environ.get("POSTGRES_PORT", 5432)
    )
    return conn
