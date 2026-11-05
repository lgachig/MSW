from datetime import datetime, timezone
import hashlib
import os
import sqlite3
from pathlib import Path


class DailyQuota:
    def __init__(self, database_path: str, daily_limit: int):
        self.database_path = database_path
        self.daily_limit = daily_limit
        if database_path != ":memory:":
            Path(database_path).parent.mkdir(parents=True, exist_ok=True)
        with self._connect() as connection:
            connection.execute(
                """CREATE TABLE IF NOT EXISTS daily_usage (
                    client_hash TEXT NOT NULL,
                    usage_date TEXT NOT NULL,
                    request_count INTEGER NOT NULL,
                    PRIMARY KEY (client_hash, usage_date)
                )"""
            )

    def consume(self, client_address: str | None) -> bool:
        day = datetime.now(timezone.utc).date().isoformat()
        client_hash = hashlib.sha256((client_address or "unknown").encode()).hexdigest()
        with self._connect() as connection:
            connection.execute("BEGIN IMMEDIATE")
            connection.execute("DELETE FROM daily_usage WHERE usage_date < ?", (day,))
            row = connection.execute(
                "SELECT request_count FROM daily_usage WHERE client_hash=? AND usage_date=?",
                (client_hash, day),
            ).fetchone()
            count = row[0] if row else 0
            if count >= self.daily_limit:
                connection.rollback()
                return False
            connection.execute(
                """INSERT INTO daily_usage(client_hash, usage_date, request_count)
                   VALUES (?, ?, 1)
                   ON CONFLICT(client_hash, usage_date)
                   DO UPDATE SET request_count=request_count + 1""",
                (client_hash, day),
            )
            connection.commit()
        return True

    def _connect(self) -> sqlite3.Connection:
        connection = sqlite3.connect(self.database_path, timeout=10)
        connection.execute("PRAGMA busy_timeout=10000")
        return connection

