SELECT symbol, volatility_stddev, return_30d_pct
FROM marts.report_volatility_ranking
ORDER BY volatility_stddev DESC;
