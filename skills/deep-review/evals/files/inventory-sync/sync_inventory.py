#!/usr/bin/env python3
"""Pull inventory counts from the feed and write them to the storefront table."""

import csv
import sqlite3
import sys
import urllib.request

FEED_URL = "https://feeds.internal/inventory/current.csv"
DB_PATH = "storefront.db"
BATCH = 500


def fetch_rows(url):
    with urllib.request.urlopen(url) as resp:
        text = resp.read().decode("utf-8")
    return list(csv.DictReader(text.splitlines()))


def write_rows(conn, rows):
    cur = conn.cursor()
    for i in range(0, len(rows), BATCH):
        chunk = rows[i:i + BATCH]
        cur.executemany(
            "UPDATE items SET on_hand = ? WHERE sku = ?",
            [(int(r["qty"]), r["sku"]) for r in chunk],
        )
        conn.commit()
    return cur.rowcount


def main():
    rows = fetch_rows(sys.argv[1] if len(sys.argv) > 1 else FEED_URL)
    conn = sqlite3.connect(DB_PATH)
    written = write_rows(conn, rows)
    conn.close()
    print(f"synced {len(rows)} rows, last batch touched {written}")


if __name__ == "__main__":
    main()
