-- Raport 1: Dzienny performance ETF
-- Pokazuje: ceny, zmianę %, wolumen, ranking dzienny
with facts as (
    select * from {{ ref('fact_etf_prices') }}
),
dates as (
    select * from {{ source('marts', 'dim_date') }}
),
etfs as (
    select * from {{ source('marts', 'dim_etf') }} where is_current = true
)
select
    d.full_date,
    d.year,
    d.month_name,
    d.day_name,
    e.symbol,
    e.etf_name,
    e.category,
    f.open,
    f.high,
    f.low,
    f.close,
    f.volume,
    f.daily_change,
    f.daily_change_pct,
    f.daily_spread_pct,
    -- Ranking dzienny po zmianie %
    rank() over (partition by d.full_date order by f.daily_change_pct desc) as daily_rank
from facts f
join dates d on f.date_key = d.date_key
join etfs  e on f.etf_key  = e.etf_key
order by d.full_date desc, f.daily_change_pct desc
