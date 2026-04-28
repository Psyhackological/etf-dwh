Fragment 1 — SCD Type 2** (wart pokazania, bo to bonus punktowy):
```etf-dwh/elt/elt_script.py#L74-100
# Expire current version
cur.execute(
    "UPDATE marts.dim_etf SET valid_to = %s, is_current = FALSE WHERE etf_key = %s",
    (today, etf_key),
)
# Insert new version
cur.execute("INSERT INTO marts.dim_etf ...")
```
> *„Jeśli atrybuty ETF się zmienią — stary rekord jest wygaszany, wstawiamy nowy. Zachowujemy pełną historię."*

**Fragment 2 — Watermark / delta**:
```etf-dwh/elt/elt_script.py#L53-58
def get_watermark(cursor, symbol: str):
    cursor.execute(
        "SELECT last_loaded_date FROM raw.etl_watermark WHERE symbol = %s",
        (symbol,)
    )
```
> *„Pobieramy tylko nowe rekordy — te po dacie z watermark. Idempotentne ładowanie przez upsert."*

**Fragment 3 — kostka OLAP**:
```etf-dwh/dbt/models/marts/olap_etf_cube.sql#L36-38
GROUP BY CUBE (e.symbol, e.category, d.year, d.quarter)
```
> *„Jeden `CUBE()` generuje 2⁴ = 16 kombinacji agregacyjnych — roll-up i drill-down bez skanowania tabeli faktów za każdym razem."*

**Screenshoty do przygotowania:**
1. 🖼️ Airflow UI — DAG graph z zielonymi taskami (udany run)
2. 🖼️ `SELECT * FROM marts.report_daily_performance LIMIT 10` — tabela wyników
3. 🖼️ `SELECT * FROM marts.report_etf_correlation` — korelacja GLD vs SPY
4. 🖼️ Metabase — gotowy wykres np. `close` w czasie dla każdego symbolu
5. 🖼️ `SELECT * FROM marts.olap_etf_cube WHERE is_year_subtotal = 0 LIMIT 5
