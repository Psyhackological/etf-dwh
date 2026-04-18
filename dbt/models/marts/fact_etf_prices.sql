{{ config(materialized='table', schema='marts') }}

WITH market AS (
    SELECT market_key
    FROM {{ source('marts', 'dim_market') }}
    WHERE market_code ILIKE '%nyse%'
    LIMIT 1
)

SELECT
    d.date_key,
    e.etf_key,
    m.market_key,

    s.open,
    s.high,
    s.low,
    s.close,
    s.volume,

    s.daily_change,
    s.daily_change_pct,
    s.daily_spread,
    s.daily_spread_pct,

    NOW() AS loaded_at

FROM {{ ref('stg_etf_prices') }} s

JOIN {{ source('marts', 'dim_date') }} d
    ON s.price_date = d.full_date

JOIN {{ source('marts', 'dim_etf') }} e
    ON s.symbol = e.symbol

CROSS JOIN market m
