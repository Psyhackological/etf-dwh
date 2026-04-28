## Schemat hurtowni danych

```
                    dim_date          ← wymiar dat, ~4000 rekordów (2020-2030)
                       │
dim_etf ───── fact_etf_prices ─────── dim_market
SCD Type 2      ~500 rekordów         NYSE / NASDAQ
```

- **`dim_date`** - wygenerowany kalendarz, atrybuty: rok, kwartał, miesiąc, dzień tygodnia, `is_weekend`
- **`dim_etf`** - słownik funduszy z **SCD Type 2** (śledzimy historię zmian atrybutów: nazwa, kategoria, indeks)
- **`dim_market`** - giełdy (NYSE, NASDAQ), statyczny wymiar
- **`fact_etf_prices`** - miary: OHLCV + `daily_change_pct`, `daily_spread_pct`
- **Warstwy:** `raw` → `staging` (widoki dbt) → `marts` (tabele faktów, wymiary, raporty, kostka)
