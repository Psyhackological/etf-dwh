SELECT
    symbol,
    price_date,
    open,
    high,
    low,
    close,
    volume,
    fetched_at
FROM raw.etf_prices
ORDER BY price_date DESC
LIMIT 20;
