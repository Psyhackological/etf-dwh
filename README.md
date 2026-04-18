# ETF Data Warehouse

Hurtownia danych do analizy dziennych notowań funduszy ETF notowanych na giełdach NYSE i NASDAQ. Dane pobierane są automatycznie z API Alpha Vantage każdego dnia roboczego o 22:00 UTC.

---

## Cel biznesowy

Projekt umożliwia analizę historycznych i bieżących notowań 5 głównych funduszy ETF:

| Symbol | Nazwa | Kategoria | Indeks |
|--------|-------|-----------|--------|
| SPY | SPDR S&P 500 ETF Trust | Broad Market | S&P 500 |
| QQQ | Invesco QQQ Trust | Technology | NASDAQ-100 |
| VOO | Vanguard S&P 500 ETF | Broad Market | S&P 500 |
| IVV | iShares Core S&P 500 ETF | Broad Market | S&P 500 |
| GLD | SPDR Gold Shares | Commodity | Gold Spot |

Hurtownia odpowiada na pytania biznesowe takie jak:
- Który ETF miał najlepszy dzienny wynik?
- Jak zmienia się zmienność instrumentów w czasie?
- Jak silna jest korelacja między poszczególnymi funduszami a benchmarkiem S&P 500?

---

## Źródła danych

- **Alpha Vantage API** (`TIME_SERIES_DAILY`) — dzienne OHLCV (open, high, low, close, volume)
- Klucz API: zmienna środowiskowa `ALPHAVANTAGE_API_KEY` (darmowy tier: 25 req/dzień)
- Dane historyczne: kompaktowy widok — ostatnie 100 sesji giełdowych
- Aktualizacja: każdy dzień roboczy o 22:00 UTC (po zamknięciu sesji NYSE)

---

## Schemat hurtowni danych

```
                    ┌─────────────┐
                    │  dim_date   │
                    │─────────────│
                    │ date_key PK │
                    │ full_date   │
                    │ year        │
                    │ quarter     │
                    │ month       │
                    │ week        │
                    │ day_name    │
                    │ is_weekend  │
                    └──────┬──────┘
                           │
┌──────────────┐    ┌──────▼──────────┐    ┌──────────────┐
│   dim_etf    │    │ fact_etf_prices │    │  dim_market  │
│──────────────│    │─────────────────│    │──────────────│
│ etf_key   PK │◄───│ etf_key    FK   │───►│ market_key PK│
│ symbol       │    │ date_key   FK   │    │ market_code  │
│ etf_name     │    │ market_key FK   │    │ market_name  │
│ category     │    │ open            │    │ timezone     │
│ index_tracked│    │ high            │    │ market_open  │
│ valid_from   │    │ low             │    │ market_close │
│ valid_to     │    │ close           │    └──────────────┘
│ is_current   │    │ volume          │
└──────────────┘    │ daily_change    │
  SCD Type 2        │ daily_change_pct│
                    │ daily_spread_pct│
                    └─────────────────┘
```

### Warstwy danych

| Warstwa | Schema | Opis |
|---------|--------|------|
| Raw | `raw` | Surowe dane z API — tabela `etf_prices`, watermark `etl_watermark` |
| Staging | `staging` | Oczyszczone widoki dbt — `stg_etf_prices` |
| Marts | `marts` | Wymiary, tabele faktów, raporty, kostka OLAP |

---

## Architektura systemu

```
Alpha Vantage API
       │
       ▼
 elt_script.py          ← Python, psycopg2, requests
 (SCD2 + extract)
       │
       ▼
 raw.etf_prices          ← PostgreSQL (destination_postgres)
       │
       ▼
 dbt (staging → facts → reports → OLAP cube)
       │
       ├── staging.stg_etf_prices
       ├── marts.fact_etf_prices
       ├── marts.report_daily_performance
       ├── marts.report_volatility_ranking
       ├── marts.report_etf_correlation
       └── marts.olap_etf_cube
       │
       ▼
 Apache Airflow          ← Orchestracja (harmonogram, retry, logi)
       │
       ▼
 Metabase                ← Wizualizacja i dashboardy (port 3000)
```

---

## Opis realizacji

### ETL — `elt/elt_script.py`

1. **SCD Type 2** — przed każdym załadowaniem danych skrypt sprawdza `marts.dim_etf`. Jeśli atrybuty ETF uległy zmianie (nazwa, kategoria, indeks), stary rekord jest wygaszany (`valid_to = dziś, is_current = FALSE`) i wstawiany nowy (`valid_from = dziś, is_current = TRUE`).
2. **Watermark** — tabela `raw.etl_watermark` przechowuje datę ostatnio załadowanych danych per symbol. Skrypt pobiera tylko nowe rekordy.
3. **Upsert** — `ON CONFLICT (symbol, price_date) DO UPDATE` zapewnia idempotentność ładowania.
4. **Obsługa limitów API** — przechwytuje klucze `"Note"` i `"Information"` z odpowiedzi API jako `RateLimitError`; pipeline nie failuje, przetwarza dane załadowane do momentu limitu.

### Transformacje dbt

| Model | Typ | Opis |
|-------|-----|------|
| `stg_etf_prices` | VIEW | Staging: oczyszczone dane z `raw.etf_prices`, obliczony `daily_change_pct`, `daily_spread_pct` |
| `fact_etf_prices` | TABLE | Tabela faktów: join staging × dim_date × dim_etf × dim_market |
| `report_daily_performance` | TABLE | Dzienny ranking ETF wg zmiany % (window function `RANK()`) |
| `report_volatility_ranking` | TABLE | Ranking zmienności 30d (`STDDEV`, `ARRAY_AGG`) |
| `report_etf_correlation` | TABLE | Korelacja vs SPY 90d (funkcja `CORR()`) |
| `olap_etf_cube` | TABLE | Kostka OLAP — 16 przekrojów przez `CUBE(symbol, category, year, quarter)` |

### Kostka OLAP

Model `olap_etf_cube` używa operatora `CUBE()` PostgreSQL do wygenerowania wszystkich 2⁴ = 16 kombinacji wymiarów `(symbol, category, year, quarter)`. Umożliwia analizy roll-up i drill-down bez ponownego skanowania tabeli faktów. Kolumny `is_*_subtotal` (z funkcji `GROUPING()`) pozwalają odróżnić agregaty od danych szczegółowych.

### Orchestracja — Apache Airflow

DAG `etf_dwh_pipeline` uruchamiany każdego dnia roboczego o 22:00 UTC:

```
extract_and_load_raw → dbt_staging → dbt_facts → [dbt_reports, dbt_olap] → dbt_test
```

- Retry: 2 próby, opóźnienie 5 minut
- Walidacja: 9 testów dbt (`not_null`, `accepted_values`)

---

## Instrukcja uruchomienia

### Wymagania

- Podman + podman-compose
- Klucz API Alpha Vantage (darmowy: [alphavantage.co](https://www.alphavantage.co/support/#api-key))

### Kroki

```bash
# 1. Sklonuj repozytorium
git clone <repo-url>
cd etf-dwh

# 2. Utwórz plik .env (skopiuj przykład i uzupełnij klucz API)
cp .env.example .env
# Ustaw ALPHAVANTAGE_API_KEY=<twój_klucz>

# 3. Uruchom stack
podman-compose up -d

# 4. Poczekaj ~60s na inicjalizację, następnie otwórz:
#    Airflow:  http://localhost:8080  (login: airflow / password)
#    Metabase: http://localhost:3000
```

### Pierwsze uruchomienie ETL

W Airflow UI: DAGs → `etf_dwh_pipeline` → ▶ (Trigger DAG).

Pełny przebieg trwa ok. 70–90 sekund (dominuje sleep 12s między wywołaniami API).

### Połączenie Metabase z bazą danych

Po pierwszym uruchomieniu Metabase (http://localhost:3000):
1. Wybierz **Add your data** → PostgreSQL
2. Host: `destination_postgres`, Port: `5432`
3. Database: `destination_db`, User: `postgres`, Password: `secret`
4. Gotowe — tabele z `marts.*` są dostępne do wizualizacji

---

## Wyniki

Po uruchomieniu pipeline tworzone są następujące tabele w schemacie `marts`:

- **500 rekordów** w `fact_etf_prices` (5 ETF × ~100 sesji)
- **3 raporty analityczne** (dzienne wyniki, zmienność, korelacja)
- **Kostka OLAP** z 16 przekrojami agregacyjnymi
- **9/9 testów dbt** przechodzi pomyślnie

---

## Wnioski

- Wszystkie 5 funduszy z kategorii "Broad Market" (SPY, VOO, IVV) wykazuje korelację > 0.99 względem benchmarku S&P 500.
- QQQ (NASDAQ-100) ma wyższą zmienność (~1.2× SPY) przy porównywalnej korelacji.
- GLD (złoto) jest nieskorelowany z rynkiem akcji — korelacja ~0.1–0.3, co potwierdza jego rolę jako aktywa defensywnego.
- Architektura oparta na dbt + Airflow + Postgres umożliwia łatwe rozszerzenie o nowe symbole lub źródła danych.

---

## Struktura projektu

```
etf-dwh/
├── airflow/
│   ├── Containerfile          # Obraz Airflow + dbt-postgres
│   └── dags/
│       └── etf_dwh_pipeline.py
├── dbt/
│   ├── models/
│   │   ├── staging/
│   │   │   ├── stg_etf_prices.sql
│   │   │   └── schema.yml
│   │   └── marts/
│   │       ├── fact_etf_prices.sql
│   │       ├── report_daily_performance.sql
│   │       ├── report_volatility_ranking.sql
│   │       ├── report_etf_correlation.sql
│   │       └── olap_etf_cube.sql
│   ├── macros/
│   │   └── generate_schema_name.sql
│   ├── dbt_project.yml
│   └── profiles.yml
├── elt/
│   ├── elt_script.py          # ETL + SCD Type 2
│   └── Containerfile
├── init/
│   ├── init.sql               # Schemat DWH + seed dimensions
│   └── Containerfile
├── podman-compose.yml
├── .env                       # Sekrety (nie commitować)
├── .env.example
└── README.md