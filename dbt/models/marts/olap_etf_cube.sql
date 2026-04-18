{{ config(materialized='table', schema='marts') }}

/*
  OLAP Cube — multi-dimensional aggregation over ETF price facts.

  Uses PostgreSQL CUBE() to pre-compute all 2^4 = 16 combinations of:
    symbol × category × year × quarter

  This enables efficient roll-up / drill-down queries without
  re-scanning the fact table on each request.

  NULL in a dimension column = subtotal across that dimension.
  Use GROUPING() flags to distinguish real NULLs from subtotals.
*/

SELECT
    COALESCE(e.symbol,        '(wszystkie)')  AS symbol,
    COALESCE(e.category,      '(wszystkie)')  AS category,
    COALESCE(d.year::TEXT,    '(wszystkie)')  AS year,
    COALESCE(d.quarter::TEXT, '(wszystkie)')  AS quarter,

    -- 1 = this row is a subtotal that collapses this dimension
    GROUPING(e.symbol)   AS is_symbol_subtotal,
    GROUPING(e.category) AS is_category_subtotal,
    GROUPING(d.year)     AS is_year_subtotal,
    GROUPING(d.quarter)  AS is_quarter_subtotal,

    COUNT(*)                                           AS trading_days,
    ROUND(AVG(f.close)::NUMERIC,             4)        AS avg_close,
    ROUND(MIN(f.close)::NUMERIC,             4)        AS min_close,
    ROUND(MAX(f.close)::NUMERIC,             4)        AS max_close,
    ROUND(SUM(f.volume)::NUMERIC,            0)        AS total_volume,
    ROUND(AVG(f.daily_change_pct)::NUMERIC,  4)        AS avg_return_pct,
    ROUND(STDDEV(f.daily_change_pct)::NUMERIC, 4)      AS volatility_stddev

FROM {{ ref('fact_etf_prices') }} f
JOIN {{ source('marts', 'dim_etf') }}  e
    ON f.etf_key  = e.etf_key  AND e.is_current = TRUE
JOIN {{ source('marts', 'dim_date') }} d
    ON f.date_key = d.date_key

GROUP BY CUBE (e.symbol, e.category, d.year, d.quarter)
