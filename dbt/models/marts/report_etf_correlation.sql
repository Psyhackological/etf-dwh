-- Raport 3: Korelacja dziennych zwrotów ETF vs SPY (benchmark)
with facts as (
    select * from {{ ref('fact_etf_prices') }}
),
dates as (
    select * from {{ source('marts', 'dim_date') }}
    where full_date >= current_date - interval '90 days'
),
etfs as (
    select * from {{ source('marts', 'dim_etf') }} where is_current = true
),
daily_returns as (
    select
        e.symbol,
        d.full_date,
        f.daily_change_pct
    from facts f
    join dates d on f.date_key = d.date_key
    join etfs  e on f.etf_key  = e.etf_key
),
spy_returns as (
    select full_date, daily_change_pct as spy_return
    from daily_returns
    where symbol = 'SPY'
)
select
    dr.symbol,
    count(*)                                                    as observations,
    round(corr(dr.daily_change_pct, sr.spy_return)::numeric, 4) as correlation_vs_spy,
    round(avg(dr.daily_change_pct), 4)                          as avg_daily_return,
    round(stddev(dr.daily_change_pct), 4)                       as return_stddev,
    case
        when corr(dr.daily_change_pct, sr.spy_return) > 0.9  then 'Bardzo wysoka'
        when corr(dr.daily_change_pct, sr.spy_return) > 0.7  then 'Wysoka'
        when corr(dr.daily_change_pct, sr.spy_return) > 0.5  then 'Umiarkowana'
        when corr(dr.daily_change_pct, sr.spy_return) > 0    then 'Niska'
        else 'Ujemna'
    end                                                         as correlation_label
from daily_returns dr
join spy_returns sr on dr.full_date = sr.full_date
where dr.symbol != 'SPY'
group by dr.symbol
order by correlation_vs_spy desc
