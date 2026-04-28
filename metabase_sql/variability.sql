SELECT symbol, volatility_stddev, return_30d_pct, stability_rank
FROM marts.report_volatility_ranking
ORDER BY stability_rank ASC;
