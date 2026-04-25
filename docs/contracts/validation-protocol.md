# Contract: Three-Warehouse Validation Protocol

## Purpose

Defines the canonical methodology for validating pipeline output trustworthiness without creating a circular dependency on FRD. Specifies warehouse definitions, reference-strategy comparison rules, scorecard tolerance framework, and promotion gates. Referenced by M4 (Backtest Engine), M5 (Metrics & Grading), M9 (Paper Trading Bridge), M12 (Live Deployment), and DataDuo's Comparative Truth Engine. Per ADR-003, this protocol is the Phase B validation methodology.

## Used By

- **M4** — runs reference strategy suite across all three warehouses
- **M5** — generates scorecards per warehouse, computes cross-warehouse deltas
- **M9** — each warehouse produces its own paper-trading lane; paper results compare to each warehouse's backtest characterization
- **M12** — promotes strategies to live only after consistency across all three paper lanes
- **DataDuo Comparative Truth Engine** — publishes Warehouse A vs Warehouse B scorecard deltas as the ongoing product deliverable

## Warehouse Definitions

| Warehouse | Identifier | Prices | Enrichment | Forward maintenance | Deployment context | Claim tested |
|-----------|------------|--------|------------|---------------------|--------------------|--------------|
| A | `warehouse_dataduo` | Free sources (Stooq primary, yfinance gap-fill) | Pipeline output from public-domain sources | IBKR daily feed enriched by pipeline (Duo-Wealth-local run) and re-ingested from free sources (DataDuo-cloud run) | Both deployments run this configuration | Pipeline produces trustworthy output from public-domain sources |
| B | `warehouse_duo_wealth` | FRD historical + IBKR forward | Pipeline output | IBKR daily feed | Duo Wealth deployment only | Pipeline works correctly when given premium price data |
| C | `warehouse_test` | FRD only (historical + one-month free update window) | Pipeline enrichment applied to FRD-sourced data | FRD one-month free update window, re-pulled per window | Duo Wealth deployment only | Pipeline logic matches FRD's native output when given the same underlying data |

Warehouse A has two build variants — Duo-Wealth-local and DataDuo-cloud — that MUST produce identical output when given identical free-source inputs. The two variants exist because Warehouse A must be buildable on both deployments per ADR-003's one-codebase principle.

## Reference Strategy Suite

A standardized strategy suite is the unit of comparison. Requirements:

- Strategies are simple and interpretable — differences across warehouses should be attributable to data, not strategy complexity
- Coverage spans: long-only, long-short, momentum, mean-reversion, moving-average crossover, volatility-targeted sizing
- All strategies conform to the Strategy Contract (`contracts/strategy-contract.md`) and are versioned per M2
- Minimum suite size: TBD during Phase 1B (initial target: 5–8 strategies)

The suite is registered in `strategies/reference/` and versioned via Git. A specific suite version is pinned for each Phase B validation run.

## Scorecard Comparison Rules

Per reference strategy, per warehouse, the backtest produces a scorecard (per `contracts/scorecard-format.md`) over an identical evaluation window. Cross-warehouse deltas are computed per metric:

| Metric | Delta computation |
|--------|-------------------|
| Total return | Absolute percentage-point difference |
| CAGR | Absolute percentage-point difference |
| Sharpe ratio | Absolute difference in Sharpe |
| Sortino ratio | Absolute difference in Sortino |
| Max drawdown | Absolute percentage-point difference in max DD magnitude |
| Max drawdown duration | Absolute day-count difference |
| Trade count | Percentage difference in count |
| Win rate | Absolute percentage-point difference |
| Profit factor | Ratio of profit factors |

Cross-warehouse comparison produces three delta sets per strategy: A-vs-B, A-vs-C, B-vs-C.

## Tolerance Thresholds (Empirical)

Tolerance thresholds are measured outputs of Phase B, not pre-specified inputs. The protocol specifies that thresholds MUST be recorded in this contract as they are measured. Initial state (to be filled during Phase B):

| Comparison | Sharpe delta | CAGR delta | Max DD delta | Trade count delta | Status |
|------------|--------------|------------|--------------|-------------------|--------|
| A vs B | TBD | TBD | TBD | TBD | Pending Phase B measurement |
| A vs C | TBD | TBD | TBD | TBD | Pending Phase B measurement |
| B vs C | TBD | TBD | TBD | TBD | Pending Phase B measurement |

Once measured, thresholds are written here and become the published trust anchor for DataDuo's Comparative Truth Engine. Subsequent threshold updates are versioned via this contract's changelog.

## Validation Sequence

1. Pin reference strategy suite version and evaluation window
2. Build all three warehouses from their respective source configurations
3. Run reference strategy suite across each warehouse via M4
4. Generate scorecards per strategy per warehouse via M5
5. Compute cross-warehouse deltas per metric
6. Record deltas against current tolerance thresholds; any delta exceeding threshold triggers M5 investigation
7. Strategies whose deltas fall within tolerance across all three comparisons (A-vs-B, A-vs-C, B-vs-C) pass the protocol and are eligible for paper trading
8. Each passing strategy runs paper trading in all three warehouse lanes simultaneously via M9
9. Paper trading results compare to that warehouse's backtest characterization per M9's divergence detector
10. Strategies that behave consistently across all three paper lanes — and track their backtest characterization in each — are eligible for live deployment via M12

## Promotion Gates

- **Backtest → Paper:** Cross-warehouse deltas within tolerance across all three comparisons
- **Paper → Live:** Paper results track backtest characterization (per-warehouse divergence within M9's tolerance) across all three lanes
- Strategies that fail in exactly one warehouse surface a specific hypothesis: the pipeline diverges for this strategy's signal sensitivities on that warehouse's data. Investigation before any further promotion.

## FRD One-Month Free Update Window

Warehouse C's forward validation uses FRD's one-month free data update window. The window is re-pulled on schedule; Warehouse C re-ingests and re-runs the reference suite. Warehouse C's forward results are compared to FRD's own native output over the same window as a direct pipeline-logic-parity check.

## Relationship to Reconciliation Engine (M1h)

M1h reconciles at the per-value level within a single warehouse's sources. This protocol operates at the strategy-scorecard level across warehouses. Both feed into accuracy claims but at different granularities. A value-level discrepancy caught by M1h may or may not produce a strategy-level scorecard delta depending on the strategy's sensitivity to the affected value.

## Open Questions

- Reference strategy suite composition (size, type mix) — Phase 1B deliverable
- Evaluation window selection — rolling vs fixed, start date, length
- Comparative Truth Engine publication cadence
- Handling of strategies passing A-vs-B but failing B-vs-C — narrowing DataDuo's claim space vs. blocking
- Paper-trading tolerance relative to backtest tolerance — same threshold or separate
- Phase B runtime budget — how long until first measurement-backed thresholds land

## Changelog

- 2026-04-19 — Initial contract created alongside ADR-003. Warehouse definitions, sequence, and empirical-tolerance framework established. Tolerance thresholds deliberately left TBD pending Phase B measurement.
