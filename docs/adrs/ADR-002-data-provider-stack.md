# ADR-002: Data Provider Stack

## Status
Accepted

## Date
2026-04-09

## Context
The data layer requires multiple data sources covering market prices, corporate actions, fundamentals, identifiers, macro data, and index constituency. The stack must support both Duo Wealth (internal, personal license acceptable) and DataDuo (future API service, redistributable sources only).

## Decision
Locked provider stack:

| Source | What | Cost | License | Duo Wealth | DataDuo |
|--------|------|------|---------|------------|---------|
| FirstRateData (FRD) | Historical backfill + validation benchmark | ~$599 one-time | Personal use only | ✅ | ❌ |
| IBKR TWS API | Ongoing daily feed (ADJUSTED_LAST + TRADES) | $0-10/month | Personal use only | ✅ | ❌ |
| SEC EDGAR | Fundamentals (XBRL), corporate actions (8-K), identifiers (CIK) | $0 | Public domain | ✅ | ✅ |
| OpenFIGI | Identifier mapping (FIGI) | $0 | Open standard | ✅ | ✅ |
| FRED/ALFRED | Macro and regime data | $0 | Public domain | ✅ | ✅ |
| fja05680/sp500 | S&P 500 constituency history | $0 | MIT license | ✅ | ✅ |

**Off the table:** Polygon, Sharadar, Simfin, Tiingo, yfinance, Stooq, EODHD (for DataDuo).
**Alpaca:** Retained for paper trading execution only, not as a data source.

## Alternatives Considered

**Polygon + Sharadar + Simfin (~$70/month recurring)** — previous locked stack. Replaced because FRD + IBKR + EDGAR achieves better coverage at lower ongoing cost, with execution-venue alignment (IBKR prices = prices you trade against).

**Norgate Data ($53/month)** — excellent survivorship-bias-free data but ongoing subscription cost and no redistribution rights for DataDuo.

## Consequences

**Enables:**
- Near-zero ongoing data cost after FRD one-time purchase
- IBKR execution-venue alignment (backtest-to-live price parity)
- EDGAR fundamentals are redistributable (DataDuo viable)
- Full control over normalization and adjustment logic

**Constrains:**
- Must build EDGAR XBRL parsing (not pre-normalized like Sharadar)
- Must build split factor reversal engine (IBKR delivers split-adjusted, not raw)
- FRD is personal use only — DataDuo cannot serve any FRD-derived price data
- No intraday data in v1 (IBKR historical intraday has pacing limits)

**Key risk:**
- Split factor engine is highest-risk component — EDGAR 8-K parsing for splits is non-trivial
- Mitigated by: FRD as validation benchmark, known test cases as unit tests, manual patch fallback

## Revisit If
- International expansion needed — EDGAR is US-only, would need additional fundamental sources
- Intraday strategies become priority — evaluate Polygon or IBKR historical minute bars
- IBKR changes data licensing terms
- FRD pricing changes significantly before purchase
