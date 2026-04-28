Przed prezentacją: upewnij się że stack działa. Skrypt startowy:

```etf-dwh/README.md#L1-5
podman-compose up -d
# poczekaj ~60s
# Airflow: http://localhost:8080
# Metabase: http://localhost:3000
```

**Plan demo (60–90 sekund):**
1. Pokaż `Airflow UI` → DAGs → `etf_dwh_pipeline`
2. Kliknij **▶ Trigger DAG**
3. Wejdź w **Graph View** — pokaż jak taski wykonują się kolejno
4. Po zakończeniu — pokaż logi ostatniego taska (`dbt_test`) — *"9/9 testów przeszło"*
5. Przełącz na Metabase / psql — pokaż wynik raportu
