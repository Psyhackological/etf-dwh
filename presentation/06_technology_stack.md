## Stos technologiczny

```
Alpha Vantage API
      │  HTTP/JSON
      ▼
elt_script.py  ──── Python 3.11, requests, psycopg2
      │              SCD2 + watermark + upsert
      ▼
raw.etf_prices ──── PostgreSQL 17
      │
      ▼
dbt ─────────────── staging → marts (facts, reports, OLAP cube)
      │
      ▼
Apache Airflow ──── DAG, schedule 22:00 UTC mon-fri, retry x2
      │
      ▼
Metabase ─────────── dashboardy i wizualizacje (port 3000)
```

| Komponent | Rola |
|---|---|
| **Python / psycopg2** | Extract z API, SCD2, ładowanie do raw |
| **PostgreSQL 17** | Baza docelowa (raw + staging + marts) |
| **dbt** | Transformacje SQL, testy jakości danych |
| **Apache Airflow** | Orchestracja, harmonogram, retry, logi |
| **Metabase** | Warstwa raportowa / wizualizacje |
| **Podman Compose** | Konteneryzacja całego stacku |
