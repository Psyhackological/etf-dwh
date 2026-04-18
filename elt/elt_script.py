import os
import time
import uuid
import requests
import psycopg2
from datetime import datetime, date

# ==============================
# CONFIG
# ==============================
API_KEY  = os.environ.get("ALPHAVANTAGE_API_KEY", "demo")
BASE_URL = "https://www.alphavantage.co/query"
SYMBOLS  = ["SPY", "QQQ", "VOO", "IVV", "GLD"]

DB_CONFIG = {
    "host":     os.environ.get("DEST_DB_HOST", "destination_postgres"),
    "port":     int(os.environ.get("DEST_DB_PORT", 5432)),
    "dbname":   os.environ.get("DEST_DB_NAME", "destination_db"),
    "user":     os.environ.get("DEST_DB_USER", "postgres"),
    "password": os.environ.get("DEST_DB_PASSWORD", "secret"),
}

RUN_ID = str(uuid.uuid4())[:8]


# ==============================
# DB HELPERS
# ==============================
def get_connection():
    return psycopg2.connect(**DB_CONFIG)


def get_watermark(cursor, symbol: str):
    cursor.execute(
        "SELECT last_loaded_date FROM raw.etl_watermark WHERE symbol = %s",
        (symbol,)
    )
    row = cursor.fetchone()
    return row[0] if row else None


def update_watermark(cursor, symbol: str, last_date: date):
    cursor.execute(
        """
        INSERT INTO raw.etl_watermark (symbol, last_loaded_date, updated_at)
        VALUES (%s, %s, NOW())
        ON CONFLICT (symbol) DO UPDATE SET
            last_loaded_date = EXCLUDED.last_loaded_date,
            updated_at = NOW()
        """,
        (symbol, last_date)
    )


# ==============================
# API FETCH (CRITICAL FIX HERE)
# ==============================
def fetch_daily(symbol: str, since_date=None) -> list:
    print(f"[{symbol}] Fetching data...")

    resp = requests.get(
        BASE_URL,
        params={
            "function":   "TIME_SERIES_DAILY",
            "symbol":     symbol,
            "outputsize": "compact",
            "datatype":   "json",
            "apikey":     API_KEY,
        },
        timeout=30,
    )

    resp.raise_for_status()
    data = resp.json()

    # ✅ FAIL ON RATE LIMIT
    if "Note" in data:
        raise RuntimeError(f"API RATE LIMIT HIT: {data['Note']}")

    # ✅ FAIL ON API ERROR
    if "Error Message" in data:
        raise RuntimeError(f"API ERROR: {data['Error Message']}")

    # ✅ FAIL IF DATA MISSING
    if "Time Series (Daily)" not in data:
        raise RuntimeError(f"INVALID API RESPONSE: {data}")

    series = data["Time Series (Daily)"]

    rows = []
    for date_str, v in series.items():
        record_date = datetime.strptime(date_str, "%Y-%m-%d").date()

        if since_date and record_date <= since_date:
            continue

        rows.append((
            symbol,
            date_str,
            float(v["1. open"]),
            float(v["2. high"]),
            float(v["3. low"]),
            float(v["4. close"]),
            int(v["5. volume"]),
        ))

    return rows


# ==============================
# LOAD
# ==============================
def load_to_postgres(rows: list) -> tuple[int, int]:
    if not rows:
        return 0, 0

    conn = get_connection()
    cur = conn.cursor()

    inserted = 0
    updated = 0

    for row in rows:
        cur.execute(
            """
            INSERT INTO raw.etf_prices
                (symbol, price_date, open, high, low, close, volume)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (symbol, price_date) DO UPDATE SET
                open = EXCLUDED.open,
                high = EXCLUDED.high,
                low = EXCLUDED.low,
                close = EXCLUDED.close,
                volume = EXCLUDED.volume,
                fetched_at = NOW()
            RETURNING (xmax = 0) AS inserted
            """,
            row,
        )

        result = cur.fetchone()
        if result and result[0]:
            inserted += 1
        else:
            updated += 1

    latest_date = max(datetime.strptime(r[1], "%Y-%m-%d").date() for r in rows)
    update_watermark(cur, rows[0][0], latest_date)

    conn.commit()
    cur.close()
    conn.close()

    return inserted, updated


# ==============================
# MAIN ETL
# ==============================
def run_etl():
    print(f"=== ETL START | run_id={RUN_ID} ===")

    for i, symbol in enumerate(SYMBOLS):
        try:
            conn = get_connection()
            cur = conn.cursor()

            watermark = get_watermark(cur, symbol)
            cur.close()
            conn.close()

            rows = fetch_daily(symbol, since_date=watermark)

            if not rows:
                print(f"[{symbol}] No new data")
            else:
                ins, upd = load_to_postgres(rows)
                print(f"[{symbol}] inserted={ins}, updated={upd}")

        except Exception as e:
            print(f"[{symbol}] ERROR: {e}")
            # ✅ THIS FAILS AIRFLOW TASK
            raise

        # ✅ avoid rate limit
        if i < len(SYMBOLS) - 1:
            time.sleep(12)

    print(f"=== ETL END | run_id={RUN_ID} ===")


# ==============================
# ENTRYPOINT
# ==============================
if __name__ == "__main__":
    run_etl()
