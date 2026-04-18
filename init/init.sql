-- ============================================================
-- ETF Data Warehouse — Star Schema
-- ============================================================

CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS marts;

-- ------------------------------------------------------------
-- RAW LAYER
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS raw.etf_prices (
    id          SERIAL PRIMARY KEY,
    symbol      VARCHAR(10)    NOT NULL,
    price_date  DATE           NOT NULL,
    open        NUMERIC(12, 4) NOT NULL,
    high        NUMERIC(12, 4) NOT NULL,
    low         NUMERIC(12, 4) NOT NULL,
    close       NUMERIC(12, 4) NOT NULL,
    volume      BIGINT         NOT NULL,
    fetched_at  TIMESTAMP      DEFAULT NOW(),
    UNIQUE (symbol, price_date)
);

CREATE TABLE IF NOT EXISTS raw.etl_audit_log (
    id              SERIAL PRIMARY KEY,
    run_id          VARCHAR(50)  NOT NULL,
    symbol          VARCHAR(10),
    status          VARCHAR(20)  NOT NULL,
    rows_fetched    INT          DEFAULT 0,
    rows_inserted   INT          DEFAULT 0,
    rows_updated    INT          DEFAULT 0,
    error_message   TEXT,
    started_at      TIMESTAMP    NOT NULL,
    finished_at     TIMESTAMP    DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS raw.etl_watermark (
    symbol           VARCHAR(10)  PRIMARY KEY,
    last_loaded_date DATE         NOT NULL,
    updated_at       TIMESTAMP    DEFAULT NOW()
);

-- ------------------------------------------------------------
-- DIMENSIONS
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS marts.dim_date (
    date_key        INT          PRIMARY KEY,
    full_date       DATE         NOT NULL,
    year            INT          NOT NULL,
    quarter         INT          NOT NULL,
    month           INT          NOT NULL,
    month_name      VARCHAR(20)  NOT NULL,
    week            INT          NOT NULL,
    day_of_month    INT          NOT NULL,
    day_of_week     INT          NOT NULL,
    day_name        VARCHAR(20)  NOT NULL,
    is_weekend      BOOLEAN      NOT NULL,
    is_trading_day  BOOLEAN      DEFAULT TRUE
);

INSERT INTO marts.dim_date
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INT  AS date_key,
    d                            AS full_date,
    EXTRACT(YEAR FROM d)::INT    AS year,
    EXTRACT(QUARTER FROM d)::INT AS quarter,
    EXTRACT(MONTH FROM d)::INT   AS month,
    TO_CHAR(d, 'Month')          AS month_name,
    EXTRACT(WEEK FROM d)::INT    AS week,
    EXTRACT(DAY FROM d)::INT     AS day_of_month,
    EXTRACT(DOW FROM d)::INT     AS day_of_week,
    TO_CHAR(d, 'Day')            AS day_name,
    EXTRACT(DOW FROM d) IN (0, 6) AS is_weekend
FROM generate_series('2020-01-01'::DATE, '2030-12-31'::DATE, '1 day') AS d
ON CONFLICT (date_key) DO NOTHING;

CREATE TABLE IF NOT EXISTS marts.dim_etf (
    etf_key         SERIAL       PRIMARY KEY,
    symbol          VARCHAR(10)  NOT NULL,
    etf_name        VARCHAR(100) NOT NULL,
    category        VARCHAR(50)  NOT NULL,
    index_tracked   VARCHAR(100),
    currency        VARCHAR(10)  DEFAULT 'USD',
    valid_from      DATE         NOT NULL,
    valid_to        DATE,
    is_current      BOOLEAN      DEFAULT TRUE
);

INSERT INTO marts.dim_etf (symbol, etf_name, category, index_tracked, currency, valid_from, valid_to, is_current)
VALUES
    ('SPY', 'SPDR S&P 500 ETF Trust',  'Broad Market', 'S&P 500',    'USD', '2020-01-01', NULL, TRUE),
    ('QQQ', 'Invesco QQQ Trust',        'Technology',   'NASDAQ-100', 'USD', '2020-01-01', NULL, TRUE),
    ('VOO', 'Vanguard S&P 500 ETF',     'Broad Market', 'S&P 500',    'USD', '2020-01-01', NULL, TRUE),
    ('IVV', 'iShares Core S&P 500 ETF', 'Broad Market', 'S&P 500',    'USD', '2020-01-01', NULL, TRUE),
    ('GLD', 'SPDR Gold Shares',         'Commodity',    'Gold Spot',  'USD', '2020-01-01', NULL, TRUE)
ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS marts.dim_market (
    market_key      SERIAL       PRIMARY KEY,
    market_code     VARCHAR(10)  NOT NULL UNIQUE,
    market_name     VARCHAR(100) NOT NULL,
    country         VARCHAR(50)  NOT NULL,
    timezone        VARCHAR(50)  NOT NULL,
    market_open     TIME         NOT NULL,
    market_close    TIME         NOT NULL,
    currency        VARCHAR(10)  NOT NULL
);

INSERT INTO marts.dim_market (market_code, market_name, country, timezone, market_open, market_close, currency)
VALUES
    ('NYSE',   'New York Stock Exchange', 'United States', 'America/New_York', '09:30', '16:00', 'USD'),
    ('NASDAQ', 'NASDAQ Stock Market',     'United States', 'America/New_York', '09:30', '16:00', 'USD')
ON CONFLICT DO NOTHING;

-- ------------------------------------------------------------
-- FACT TABLE
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS marts.fact_etf_prices (
    fact_key         SERIAL       PRIMARY KEY,
    date_key         INT          NOT NULL REFERENCES marts.dim_date(date_key),
    etf_key          INT          NOT NULL REFERENCES marts.dim_etf(etf_key),
    market_key       INT          NOT NULL REFERENCES marts.dim_market(market_key),
    open             NUMERIC(12, 4) NOT NULL,
    high             NUMERIC(12, 4) NOT NULL,
    low              NUMERIC(12, 4) NOT NULL,
    close            NUMERIC(12, 4) NOT NULL,
    volume           BIGINT         NOT NULL,
    daily_change     NUMERIC(12, 4),
    daily_change_pct NUMERIC(8, 4),
    daily_spread     NUMERIC(12, 4),
    daily_spread_pct NUMERIC(8, 4),
    loaded_at        TIMESTAMP    DEFAULT NOW(),
    UNIQUE (date_key, etf_key)
);

