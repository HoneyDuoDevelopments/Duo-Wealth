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

| Warehouse | Identifier | Lifetime | Bootstrap source(s) | Forward maintenance | Enrichment | Deployment context | Claim tested |
|-----------|------------|----------|---------------------|---------------------|------------|--------------------|--------------|
| A | `warehouse_dataduo` | Persistent — runs indefinitely | Free sources (Stooq primary, yfinance gap-fill) historical pull through respective adapters | Duo-Wealth-side variant: IBKR daily feed re-ingested through pipeline. DataDuo-side variant: ongoing free-source ingestion (no IBKR). Both variants must produce identical enrichment output. | Pipeline output from public-domain sources | Both deployments run this configuration | Pipeline produces trustworthy output from public-domain sources; A is also the configuration DataDuo's Build-Your-Own-Warehouse methodology produces |
| B | `warehouse_duo_wealth` | Permanent — Duo Wealth's production research warehouse | FRD historical, ingested ONCE through the FRD adapter, unadjusted, pipeline-enriched, written to canonical and research stores. Single bootstrap event. | IBKR daily feed through the IBKR adapter, unadjusted, pipeline-enriched, appended to canonical and research stores. FRD is NOT in B's operational loop after bootstrap. | Pipeline output | Duo Wealth deployment only | Pipeline works correctly when given premium price data |
| C | `warehouse_test` | Temporary — bounded by FRD update access | FRD historical through the FRD adapter | Fresh FRD data on rolling dates via FRD's update window (initially the one-month free window; extensible if an FRD subscription is maintained); re-pulled per window. Comparison continues only as long as FRD update access continues. | Pipeline enrichment applied to FRD-sourced data | Duo Wealth deployment only | Pipeline logic matches FRD's native output when given the same underlying data |

Warehouse A's Duo-Wealth-side and DataDuo-side variants exist because A must be buildable on both deployments per ADR-003's one-codebase principle. Both variants must produce identical enrichment output when given identical free-source inputs.

## Lifetime and FRD Dependency

Each warehouse has a distinct lifetime and a distinct relationship to FRD. The three-way symmetry of the protocol is a Phase B characteristic, not a steady-state characteristic.

- **Warehouse A is persistent.** It runs indefinitely alongside Warehouse B because the Comparative Truth Engine deliverable depends on continuously refreshed A-vs-B scorecard deltas as time advances. A single Phase B snapshot would go stale within months and the comparative claim would be a frozen historical artifact instead of a live trust anchor. A is also the configuration DataDuo's "Build Your Own Warehouse" methodology produces — running it locally validates that DataDuo's product actually works.
- **Warehouse B is permanent.** It is Duo Wealth's ongoing production warehouse for strategy research. FRD's role in B is a one-time historical bootstrap: the FRD adapter ingests FRD historical exactly once, the pipeline reverses FRD's adjustments to unadjusted raw, applies its own EDGAR-derived adjustment factors, and writes canonical and research stores. After bootstrap, B is maintained forward solely by IBKR daily ingestion through the IBKR adapter. FRD is not required for B's ongoing operation.
- **Warehouse C is temporary.** Its purpose is to compare pipeline-on-FRD-data against FRD's native output on fresh dates as they roll in. C therefore requires ongoing FRD update access. C is dismantled when FRD update access ends.

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

## FRD Update Access and Warehouse C Lifetime

Warehouse C's forward validation depends on ongoing FRD update access. Initially this is FRD's one-month free data update window; the window is re-pulled on schedule, Warehouse C re-ingests via the FRD adapter, and the reference suite is re-run with C's output compared to FRD's own native output over the same window as a direct pipeline-logic-parity check. The same arrangement extends naturally if an FRD subscription is maintained.

When FRD update access ends, Warehouse C is dismantled. This is by design — C exists specifically to perform pipeline-logic-parity checks against fresh FRD data, and that comparison is the only thing C does. Warehouse A and Warehouse B are unaffected by C's dismantling. A continues running on its respective forward-maintenance source (free / IBKR), B continues running on IBKR alone, and the Comparative Truth Engine continues consuming A-vs-B scorecard deltas.

## Post-Phase-B Steady State

After Phase B validation completes:

- Warehouse A and Warehouse B both continue running indefinitely.
- Warehouse C is dismantled when FRD update access ends.
- The Comparative Truth Engine continuously refreshes from ongoing A-vs-B scorecard comparison. New scorecard deltas are produced as both warehouses ingest the same forward dates from their respective sources, enrich through identical pipeline logic, and re-run the reference strategy suite.
- Loss of FRD update access has no operational impact on A or B. It ends C's specific comparison; it does not degrade Duo Wealth's research warehouse, nor does it degrade DataDuo's ongoing product.

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
- 2026-04-24 — Refined warehouse framing to make lifetime and FRD-dependency distinctions explicit. Added Lifetime column to warehouse table; split price column into bootstrap-time vs forward-maintenance to clarify that Warehouse B uses FRD as a one-time historical bootstrap and is maintained forward by IBKR thereafter. Added "Lifetime and FRD Dependency" and "Post-Phase-B Steady State" sections. Reframed "FRD One-Month Free Update Window" section as "FRD Update Access and Warehouse C Lifetime" to clarify that C is dismantled when FRD updates end while A and B continue indefinitely.
