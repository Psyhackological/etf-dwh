SELECT symbol, correlation_vs_spy, correlation_label
FROM marts.report_etf_correlation
ORDER BY correlation_vs_spy DESC;
