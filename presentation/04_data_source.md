## Źródło danych

https://www.alphavantage.co/documentation/

| Źródło | Alpha Vantage REST API |
| **Endpoint** | `TIME_SERIES_DAILY` |
| **Format** | JSON → OHLCV (Open, High, Low, Close, Volume) |
| **Częstotliwość** | 1×/dobę, każdy dzień roboczy o 22:00 UTC |
| **Zakres historyczny** | Ostatnie ~100 sesji giełdowych (compact output) |
| **Symbole** | SPY, QQQ, VOO, IVV, GLD |
| **Ograniczenia** | Darmowy tier: 25 req/dzień → obsługa rate-limit wbudowana w pipeline |
| **Dostęp** | Klucz API jako zmienna środowiskowa `ALPHAVANTAGE_API_KEY` |
