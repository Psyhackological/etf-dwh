SELECT d.full_date, e.symbol, f.close
FROM marts.fact_etf_prices f
JOIN marts.dim_date d ON f.date_key = d.date_key
JOIN marts.dim_etf  e ON f.etf_key  = e.etf_key
WHERE e.is_current = true
ORDER BY d.full_date ASC;
