#!/usr/bin/env python3
"""Read-only query runner for the s3pIntegrate Postgres.

Usage: db.py <sql-file> [out.csv]
Runs every statement in the file (split on ';' at end of line).
Prints each result as text; when out.csv is given, the last result
is written there as CSV with a header row.
Credentials come from cloud/backup/.env; never printed.
"""
import csv
import re
import sys
import time

import psycopg2

ENV = "/Users/barista/Developer/s3-platform/cloud/backup/.env"
OPTIONS = (
    "-c default_transaction_read_only=on "
    "-c statement_timeout=120s "
    "-c timezone=Europe/Moscow"
)


def load_env(path):
    out = {}
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, val = line.split("=", 1)
            out[key.strip()] = val.strip().strip('"').strip("'")
    return out


def connect():
    env = load_env(ENV)
    conn = psycopg2.connect(
        host=env["PGHOST"],
        port=env.get("PGPORT", "5432"),
        dbname=env["PGDATABASE"],
        user=env["PGUSER"],
        password=env["PGPASSWORD"],
        connect_timeout=20,
        options=OPTIONS,
    )
    conn.set_session(readonly=True, autocommit=True)
    return conn


def split_statements(sql):
    parts = re.split(r";[ \t]*\n", sql)
    keep = []
    for p in parts:
        lines = [ln for ln in p.splitlines() if ln.strip() and not ln.strip().startswith("--")]
        if lines:
            keep.append(p.strip())
    return keep


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    sql_path = sys.argv[1]
    out_csv = sys.argv[2] if len(sys.argv) > 2 else None
    with open(sql_path, encoding="utf-8") as fh:
        statements = split_statements(fh.read())
    conn = connect()
    cur = conn.cursor()
    last = None
    for i, stmt in enumerate(statements, 1):
        t0 = time.time()
        cur.execute(stmt)
        if cur.description is None:
            print(f"-- [{i}] ok ({time.time()-t0:.1f}s)")
            continue
        cols = [d[0] for d in cur.description]
        rows = cur.fetchall()
        last = (cols, rows)
        print(f"-- [{i}] {len(rows)} rows ({time.time()-t0:.1f}s)")
        if not out_csv or i < len(statements):
            print(" | ".join(cols))
            for r in rows[:200]:
                print(" | ".join("" if v is None else str(v) for v in r))
            if len(rows) > 200:
                print(f"... {len(rows)-200} more rows")
    if out_csv and last:
        cols, rows = last
        with open(out_csv, "w", newline="", encoding="utf-8") as fh:
            w = csv.writer(fh)
            w.writerow(cols)
            w.writerows(rows)
        print(f"-- wrote {len(rows)} rows to {out_csv}")
    conn.close()


if __name__ == "__main__":
    main()
