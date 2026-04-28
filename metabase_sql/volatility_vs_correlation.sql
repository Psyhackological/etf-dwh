SELECT
  c.symbol,
  v.volatility_stddev AS risk,
  c.correlation_vs_spy AS correlation,
  ABS(c.avg_daily_return) AS return_size,
  c.correlation_label
FROM
  marts.report_etf_correlation c
  JOIN marts.report_volatility_ranking v ON c.symbol = v.symbol
UNION ALL
SELECT
  'SPY' AS symbol,
  v.volatility_stddev AS risk,
  1.0 AS correlation,
  ABS(v.return_30d_pct / 100) AS return_size,
  'Benchmark' AS correlation_label
FROM
  marts.report_volatility_ranking v
WHERE
  v.symbol = 'SPY'
ORDER BY
  correlation DESC;
