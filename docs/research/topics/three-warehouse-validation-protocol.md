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

| Warehouse | Lifetime | Bootstrap source(s) | Forward maintenance | Enrichment | Tests the claim |
|-----------|----------|---------------------|---------------------|------------|-----------------|
| A — DataDuo Warehouse | Persistent — runs indefinitely | Free sources (Stooq primary, yfinance gap-fill) historical pull through respective adapters | Duo-Wealth-side variant: IBKR daily feed re-ingested through pipeline. DataDuo-side variant: ongoing free-source ingestion (no IBKR). | Pipeline output from public-domain sources | "The pipeline produces trustworthy output from public-domain sources." A is also the configuration DataDuo's Build-Your-Own-Warehouse methodology produces. |
| B — Duo Wealth Warehouse | Permanent | FRD historical, ingested ONCE through the FRD adapter; pipeline-unadjusted; pipeline-enriched. | IBKR daily feed through the IBKR adapter; pipeline-unadjusted; pipeline-enriched. FRD is NOT in B's operational loop after bootstrap. | Pipeline output | "The pipeline works correctly when given premium price data." |
| C — Test Warehouse | Temporary — bounded by FRD update access | FRD historical through the FRD adapter | Fresh FRD data on rolling dates via FRD's update window (free or subscription); comparison continues only as long as FRD update access continues. | Pipeline enrichment applied to FRD-sourced data | "Our pipeline logic matches FRD's native output when given the same underlying data." |

Each warehouse tests a distinct claim; failures localize. If A diverges from B, either public-domain sources are insufficient for the claim space or the pipeline's source-agnostic guarantee is leaky. If C diverges from FRD's native output, pipeline logic has a bug. If A and C both match B within tolerance, the pipeline's independence claim holds.

The three-way symmetry of the protocol is a Phase B characteristic, not a steady-state characteristic. After Phase B, A and B continue indefinitely; C is dismantled when FRD update access ends.

**Validation sequence is strategy-driven, not data-point-driven. [Confirmed]**

1. Run identical reference strategies across all three warehouses in backtest (M4).
2. Generate scorecards (M5) — Sharpe, CAGR, max drawdown, trade count, win rate.
3. Compare scorecards across warehouses within an empirically-measured tolerance threshold.
4. Strategies that pass across all three promote to paper trading (M9) from each warehouse.
5. Compare paper trading results against backtest characterization for each warehouse.
6. Only strategies that behave consistently across all three environments earn the right to go live.

This tests strategy robustness as a byproduct of testing pipeline accuracy. A strategy whose scorecard differs wildly across warehouses is either over-fit to a specific data source or exposing a pipeline bug — either way, not promotable.

**FRD update access is load-bearing for Warehouse C only — not for Warehouse B. [Confirmed]**
FRD provides a one-month free data update window (extensible if a subscription is maintained). Warehouse C uses it to validate that the pipeline's enrichment logic applied to FRD-sourced prices continues to match FRD's native output over fresh time periods; without ongoing FRD updates, C's specific comparison cannot continue and C is dismantled. Warehouse B's relationship to FRD is different: B uses FRD as a one-time historical bootstrap source via the FRD adapter, then is maintained forward by IBKR alone. After B's bootstrap completes, FRD access is no longer relevant to B's operation.

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
- **Post-Phase-B persistence:** Warehouses A and B continue running indefinitely after Phase B validation completes. Warehouse C is dismantled when FRD update access ends. The protocol's three-way symmetry is a Phase B characteristic, not a steady-state characteristic.
- **Warehouse A as DataDuo product feed:** A is not a temporary validation scaffold. It IS the configuration DataDuo's Build-Your-Own-Warehouse methodology produces, and its continuous operation is what supplies the Comparative Truth Engine with refreshed A-vs-B scorecard deltas as time advances. Without A running continuously after Phase B, the Comparative Truth Engine becomes a frozen historical snapshot.
- **Warehouse B as Duo Wealth production warehouse:** B is permanent. FRD's role in B is a one-time historical bootstrap; B is maintained forward by IBKR daily feed alone. Loss of FRD access after B's bootstrap has no operational impact on B.
- **Warehouse C's distinct FRD dependency:** C requires ongoing FRD update access because its specific comparison — pipeline-on-FRD-data vs FRD's native output on fresh dates — needs fresh FRD data on new dates. C is dismantled when FRD updates end; A and B are unaffected.

## Recommended Decision

Adopt the three-warehouse validation protocol as the canonical Phase B methodology per ADR-003. Document the protocol as a cross-cutting contract (`contracts/validation-protocol.md`) so that M4, M5, M9, and M12 all reference the same warehouse definitions and comparison rules.

Tolerance thresholds are recorded as empirical outputs into the contract during Phase B; the contract is updated when measurements are made.

## Unresolved Questions

- Tolerance thresholds for Sharpe, CAGR, max-DD deltas across warehouses (open question #2)
- Reference strategy suite composition — how many, what types, how selected
- Comparative Truth Engine refresh cadence (daily, weekly, monthly, per-rerun)
- Handling of strategies that pass Warehouses A and B but fail Warehouse C — does this indicate the pipeline diverges from FRD on a specific class of instruments, and does that invalidate DataDuo's claim or just narrow it
- Paper-trading comparison tolerance vs backtest tolerance — are they the same threshold or separate
