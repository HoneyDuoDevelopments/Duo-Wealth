# Three-Warehouse Validation Protocol

## Question

How does the pipeline validate that its output is trustworthy without creating a circular dependency on FRD (whose role per ADR-003 is validator, not primary source)? What methodology produces measurable accuracy claims that support DataDuo's Comparative Truth Engine deliverable?

## Why It Matters

A pipeline that claims to be source-agnostic and independent of FRD needs a validation method that actually tests those claims — not a validation method that collapses into "does the pipeline agree with FRD." DataDuo's entire value proposition ("public-domain enrichment close enough to premium that you don't need the premium feed") rests on producing an honest, measurable accuracy delta against a premium-data reference. Without a rigorous validation protocol, DataDuo ships a claim it cannot substantiate.

## Sources Reviewed

- ADR-003 Part 1.4 (three-warehouse validation protocol specification)
- ADR-002 (FRD positioning as validation benchmark)
- April 2026 architectural audit Finding 11 (three-warehouse protocol as new scope)
- FRD's one-month free update window documentation (used as forward-validation source)
- Cross-session skeptical review (Gemini, GPT) on survivorship and validation gaps
- Blueprint M4 (Backtest Engine) and M5 (Metrics & Grading) — consumers of the protocol output

## Key Findings

**Three warehouses triangulate three independent claims simultaneously. [Confirmed — architectural decision, ADR-003]**

| Warehouse | Prices | Enrichment | Forward maintenance | Tests the claim |
|-----------|--------|------------|---------------------|-----------------|
| A — DataDuo Warehouse | Free sources (Stooq primary, yfinance gap-fill) | Pipeline output from public-domain sources | IBKR daily feed enriched by pipeline (Duo-Wealth-side), re-ingested from free sources (DataDuo-side) | "The pipeline produces trustworthy output from public-domain sources." |
| B — Duo Wealth Warehouse | FRD historical + IBKR forward | Pipeline output | IBKR daily feed | "The pipeline works correctly when given premium price data." |
| C — Test Warehouse | FRD only | Pipeline enrichment applied to FRD-sourced data | FRD one-month free update window | "Our pipeline logic matches FRD's native output when given the same underlying data." |

Each warehouse tests a distinct claim; failures localize. If A diverges from B, either public-domain sources are insufficient for the claim space or the pipeline's source-agnostic guarantee is leaky. If C diverges from FRD's native output, pipeline logic has a bug. If A and C both match B within tolerance, the pipeline's independence claim holds.

**Validation sequence is strategy-driven, not data-point-driven. [Confirmed]**

1. Run identical reference strategies across all three warehouses in backtest (M4).
2. Generate scorecards (M5) — Sharpe, CAGR, max drawdown, trade count, win rate.
3. Compare scorecards across warehouses within an empirically-measured tolerance threshold.
4. Strategies that pass across all three promote to paper trading (M9) from each warehouse.
5. Compare paper trading results against backtest characterization for each warehouse.
6. Only strategies that behave consistently across all three environments earn the right to go live.

This tests strategy robustness as a byproduct of testing pipeline accuracy. A strategy whose scorecard differs wildly across warehouses is either over-fit to a specific data source or exposing a pipeline bug — either way, not promotable.

**FRD's one-month free update window is load-bearing for Warehouse C forward validation. [Confirmed]**
FRD provides a one-month free data update window. Warehouse C uses it to validate that the pipeline's enrichment logic applied to FRD-sourced prices continues to match FRD's native output over fresh time periods. Without this window, Warehouse C's validation is historical-only.

**Tolerance thresholds must be measured empirically, not pre-specified. [Open question — tracked as existing open question #2]**
Acceptable Sharpe-delta, CAGR-delta, and max-DD-delta across warehouses cannot be set a priori without measurement. They are Phase B outputs, not Phase B inputs. Once measured, they become the published trust anchor for the Comparative Truth Engine.

**The protocol produces the measurement that the Comparative Truth Engine publishes. [Confirmed]**
The warehouse-to-warehouse scorecard delta (A vs B specifically) is the accuracy claim DataDuo stakes its reputation on. The protocol is therefore not just an internal validation — it is the ongoing data generator for a public DataDuo deliverable.

**Reconciliation engine (M1h) operates orthogonally to the three-warehouse protocol. [Confirmed]**
M1h reconciles sources within a single warehouse (e.g., Stooq vs yfinance for Warehouse A's price ingestion). The three-warehouse protocol compares entire warehouses against each other at the scorecard level. The two layers of validation are complementary — M1h catches per-value discrepancies at ingestion time; the three-warehouse protocol catches systemic deltas at the strategy-outcome level.

## Implications

- **Phase B (Validation):** Becomes a structured three-warehouse build and comparison phase, sequenced between Phase 1 and Phase 2 in the roadmap.
- **Infrastructure:** Three parallel warehouses run simultaneously during Phase B. The pipeline codebase is shared; the deployment configurations differ per ADR-003 (Duo Wealth vs DataDuo deployment modes, plus Test warehouse as a third configuration).
- **Reference strategy suite:** A standardized strategy suite (likely in Phase 1B) must be defined for comparative backtesting. Start simple — momentum, mean-reversion, moving-average crossover — so differences are interpretable.
- **Tolerance thresholds:** Documented empirically in `contracts/validation-protocol.md` as they are measured during Phase B. Not pre-specified.
- **DataDuo Comparative Truth Engine:** Publishes Warehouse A vs Warehouse B scorecard deltas as an ongoing product deliverable, refreshed on a defined cadence.
- **Paper trading:** Each warehouse produces its own paper-trading lane; strategies promote to live only after behaving consistently across all three paper lanes plus their backtest characterizations.

## Recommended Decision

Adopt the three-warehouse validation protocol as the canonical Phase B methodology per ADR-003. Document the protocol as a cross-cutting contract (`contracts/validation-protocol.md`) so that M4, M5, M9, and M12 all reference the same warehouse definitions and comparison rules.

Tolerance thresholds are recorded as empirical outputs into the contract during Phase B; the contract is updated when measurements are made.

## Unresolved Questions

- Tolerance thresholds for Sharpe, CAGR, max-DD deltas across warehouses (open question #2)
- Reference strategy suite composition — how many, what types, how selected
- Comparative Truth Engine refresh cadence (daily, weekly, monthly, per-rerun)
- Handling of strategies that pass Warehouses A and B but fail Warehouse C — does this indicate the pipeline diverges from FRD on a specific class of instruments, and does that invalidate DataDuo's claim or just narrow it
- Paper-trading comparison tolerance vs backtest tolerance — are they the same threshold or separate
