# Cel biznesowy

## Problem
Dane o notowaniach ETF są dostępne przez API w postaci surowych OHLCV per dzień są trudne do analizy porównawczej bez agregacji.

## Rozwiązanie

Hurtownia danych automatycznie zbiera, czyści i agreguje dane z pięciu głównych funduszy (`SPY`, `QQQ`, `VOO`, `IVV`, `GLD`), umożliwiając analizę trendów, zmienności i korelacji.

## Przykowi użytkownicy
Np.: analitycy finansowi, zarządzający portfelem, inwestorzy indywidualni.

## Pytania biznesowe, na które odpowiada system:
- Który ETF miał najlepszy wynik w danym dniu/kwartale?
- Jak zmienia się zmienność funduszy w czasie?
- Jak silnie GLD (złoto) koreluje z rynkiem akcji?
