-- Raport 2: Ranking zmienności ETF — ostatnie 30 dni sesji
with facts as (
    select * from {{ ref('fact_etf_prices') }}
),
dates as (
    select * from {{ source('marts', 'dim_date') }}
    where full_date >= current_date - interval '30 days'
),
etfs as (
    select * from {{ source('marts', 'dim_etf') }} where is_current = true
),
base as (
    select
        e.symbol,
        e.etf_name,
        e.category,
        f.close,
        f.daily_change_pct,
        f.daily_spread_pct,
        f.volume,
        d.full_date
    from facts f
    join dates d on f.date_key = d.date_key
    join etfs  e on f.etf_key  = e.etf_key
),
bookends as (
    select
        symbol,
        (array_agg(close order by full_date asc))[1]  as first_close,
        (array_agg(close order by full_date desc))[1] as latest_close
    from base
    group by symbol
)
select
    b.symbol,
    b.etf_name,
    b.category,
    count(b.full_date)                                                          as trading_days,
    round(bk.latest_close, 4)                                                   as latest_close,
    min(b.close)                                                                as period_low,
    max(b.close)                                                                as period_high,
    round(((bk.latest_close - bk.first_close) / nullif(bk.first_close, 0)) * 100, 4) as return_30d_pct,
    round(stddev(b.daily_change_pct), 4)                                        as volatility_stddev,
    round(avg(b.daily_spread_pct), 4)                                           as avg_spread_pct,
    round(avg(b.volume), 0)                                                     as avg_daily_volume,
    -- Ranking: im niższy stddev tym stabilniejszy ETF
    rank() over (order by stddev(b.daily_change_pct) asc)                       as stability_rank
from base b
join bookends bk on b.symbol = bk.symbol
group by b.symbol, b.etf_name, b.category, bk.latest_close, bk.first_close
order by volatility_stddev asc
