with source as (
    select
        symbol,
        price_date,
        open,
        high,
        low,
        close,
        volume,
        round(close - open, 4)                                  as daily_change,
        round(((close - open) / nullif(open, 0)) * 100, 4)     as daily_change_pct,
        round(high - low, 4)                                    as daily_spread,
        round(((high - low) / nullif(close, 0)) * 100, 4)      as daily_spread_pct,
        fetched_at
    from raw.etf_prices
)
select * from source

