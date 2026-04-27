# HoneyDuo Wealth — Roadmap

## Current Status

**Phase:** Pre-build — architecture and documentation complete (April 2026 audit complete; ADR-003 accepted; Blueprint v0.4; multi-source adapter and lifecycle registry locked). Next code work begins at Phase 1A-A1 (Universe and Lifecycle Foundation).
**Last updated:** April 24, 2026

-----

## Phase Overview

```
PHASE 0 ─── Project Setup & Research Capture (COMPLETE)
    │
PHASE 1A ── Data Foundation
    │       A1 — Universe and Lifecycle Foundation (no prices yet)
    │       A2 — Single-Ticker Price Pipeline (AAPL via Stooq adapter)
    │       A3 — Scale and Multi-Source Coverage
    │
    ├────── MILESTONE: First Reproducible Result
    │       (data-layer reproducibility gate before strategy/backtest work)
    │
PHASE 1B ── Strategy & Backtest Core (incl. reference strategy suite)
    │
PHASE 1C ── Evaluation & Tracking
    │
    ├────── MILESTONE: Tier 1 — research workbench operational
    │
PHASE B ─── Three-Warehouse Validation
    │       Build A, B, C in parallel; measure tolerance thresholds
    │
    ├────── MILESTONE: Pipeline trustworthiness measured
    │       Warehouses A and B transition to permanent operation;
    │       Warehouse C continues until FRD update access ends.
    │
PHASE C ─── Capability Domain Expansion (runs against Warehouse B)
    │       Short interest, holdings, insider, direct macro
    │
PHASE 2A ── Tournament & Paper Trading
    │
PHASE 2B ── Graveyard & Governance
    │
    ├────── MILESTONE: Tier 2 — Duo Wealth validation pipeline
    │
PHASE 3A ── Portfolio & Risk Engine
    │
PHASE 3B ── Live Deployment & Alerts
    │
    ├────── MILESTONE: Tier 3 — Duo Wealth deployed with real capital
    │
PHASE 4 ─── Intelligence Layer
    │
    └────── MILESTONE: Tier 4 — system adapts to market conditions

DATADUO LAUNCH (parallel deployment track)
    Prerequisites: Phase B complete, Phase C surface area, IP attorney
    Deliverables: Enrichment API, Build-Your-Own-Warehouse methodology,
                  Comparative Truth Engine (fed by Warehouse A continuously)
    Independent of Phase 2/3/4
```

Why sub-phases within tiers: each sub-phase has clear exit criteria and delivers something usable on its own. You can pause between 1A and 1B and still have a working data layer. You can run backtests after 1C without needing tournament infrastructure. Each phase is a stable plateau, not a cliff.

-----

## PHASE 0: Project Setup & Research Capture

**Status:** COMPLETE

**Goal:** Get the repo standing, docs committed, and capture research already done so nothing lives only in chat history.

**Work completed:**

- GitHub repo with full folder skeleton from docs architecture plan
- `blueprint.md` v0.4 (multi-deployment pipeline architecture, three-part DataDuo product, M1f/M1g/M1h sub-modules)
- `roadmap.md` (this document, v1.1)
- `knowledge-architecture-plan.md` v1.2
- ADR-001 (storage architecture: PostgreSQL + Parquet + DuckDB), ADR-002 (data provider stack), ADR-003 (independent public-domain pipeline architecture)
- Cross-cutting contracts: `price-source-adapter.md`, `reconciliation-report-schema.md`, `validation-protocol.md`, `data-provenance-schema.md`
- Research topics: data-landscape-review-april-2026, dataduo-product-scope, sp-400-600-constituency-reconstruction, three-warehouse-validation-protocol
- Architectural audit at `audits/System_Audit_And_Documentation_Update_Plan_April_2026.md`

**Exit criteria met:**

- Repo exists with full structure
- All architectural decisions captured in docs (nothing lives only in chat)
- Any future session can start by uploading blueprint + roadmap and be oriented in 2 minutes

-----

## PHASE 1A: Data Foundation

**Goal:** Build M1 (Data Layer) — the system can ingest universe, lifecycle, and price data through the multi-source adapter pattern, with cross-source reconciliation. Universe and lifecycle are built before any prices per the universe-and-lifecycle-first principle (Blueprint Principle 9 / ADR-003 / Audit Finding 14).

**Modules:** M1 (Data Layer), including the new sub-modules M1f (Lifecycle Registry), M1g (Price Source Adapter Layer), M1h (Reconciliation Engine).

**Contracts referenced (already written in Phase 0):** `price-source-adapter.md`, `reconciliation-report-schema.md`, `data-provenance-schema.md`, `validation-protocol.md`.

### Sub-phase A1 — Universe and Lifecycle Foundation (2-3 weeks)

**Goal:** Authoritative "every ticker, every index, every lifecycle transition 2005-present" dataset, built from public-domain sources only. No prices yet.

**Work:**

- Write `modules/m01f-lifecycle-registry.md` spec
- Build lifecycle registry from SEC Form 25, 8-K Item 3.01, OpenFIGI, EDGAR CIK history
- Build index membership history:
  - S&P 500 from fja05680 + datasets/s-and-p-500-companies (community-maintained sources)
  - S&P 400 from MDY N-PORT historical holdings (ETF-as-universe-proxy)
  - S&P 600 from IJR N-PORT historical holdings
  - **Build sequence (sequential, not parallel):**
    - S&P 500 first via fja05680 + datasets/s-and-p-500-companies + press release reconciliation — proves the architecture before extending
    - MDY/IJR after S&P 500 work proves the architecture — extends universe coverage via N-PORT parsing, reusing the corporate action event log and adjustment engines built during S&P 500 work
    - Phase 1A-A1 does not exit until S&P 500 and MDY/IJR coverage are both in place
    - Rationale: splits and dividends are instrument-keyed not index-keyed, so the heavy infrastructure (event log, adjustment engines) carries forward; only membership reconstruction logic is index-specific. See `research/topics/phase-1-build-plan.md` Section 1.6.
- Cross-reconcile across sources; flag gaps and conflicts
- Build point-in-time universe query interface (returns instruments active on queried date, not currently active)
- Write `modules/m01d-universe-manager.md` covering M1d's public-domain universe reconstruction
- Empirical source verification gate (before Stage 1 implementation begins)
  - Verify what Stooq actually delivers for known test cases (AAPL, a delisted ticker, a high-dividend-history name, a dual-class share)
  - Verify what yfinance actually delivers for the same test cases — confirm adjusted and unadjusted exposed as expected, measure delisted-ticker coverage
  - Verify SEC and OpenFIGI API behavior for identity-resolution hard cases
  - Document results in `research/topics/source-empirical-verification-stooq-yfinance.md`
  - Stage 1 implementation does not begin until empirical verification is complete and documented

**Exit criteria:**

- Point-in-time queries against 2005-present return the correct universe at any historical date
- All known delisted tickers are present with correct delisting dates
- Index membership transitions are documented with source attribution
- No price work has begun

### Sub-phase A2 — Single-Ticker Price Pipeline (1-2 weeks)

**Goal:** AAPL's price history flows end-to-end through the pipeline — ingested from Stooq via the price source adapter, unadjusted, re-enriched with pipeline-derived adjustment factors, written to canonical and research stores with full provenance.

**Work:**

- Write `modules/m01g-price-source-adapters.md` spec
- Implement the adapter interface per `contracts/price-source-adapter.md`
- Implement Stooq adapter (primary public-domain price source; mandatory `reverse_adjust`)
- Build raw store (M1a), canonical store (M1b), research store (M1c) infrastructure per ADR-001 storage tiers
- Build EDGAR 8-K Item 5.03 parser for adjustment factor derivation
- Apply unadjust-then-re-adjust to AAPL across its full history
- Validate output against known corporate action sequences (splits, special dividends)
- Attach data provenance metadata per `contracts/data-provenance-schema.md`

**Exit criteria:**

- AAPL price history queryable at all storage tiers
- Provenance metadata attached to every value
- Pipeline-derived adjustments reproducible
- Adapter interface validated by single source — ready for multi-source extension

### Sub-phase A3 — Scale and Multi-Source Coverage (2-3 weeks)

**Goal:** Full universe coverage (S&P 500 + S&P 400) with multi-source reconciliation operational. M1 ready to feed downstream modules.

**Work:**

- Implement yfinance adapter (gap-fill for Stooq)
- Implement IBKR adapter (forward feed; Duo Wealth deployment only)
- Implement FRD adapter (Warehouse B historical bootstrap; Warehouse C ongoing comparison; Duo Wealth deployment only)
- Write `modules/m01h-reconciliation-engine.md` spec
- Build M1h Reconciliation Engine — produces discrepancy records per `contracts/reconciliation-report-schema.md`
- Build M1e Data Quality Validator gating (consumes M1h output)
- Scale ingestion across full universe (active + delisted tickers from 2005-present)
- Per-adapter unit tests on known corporate action sequences
- Adapter-registration enforcement: DataDuo deployment refuses `ibkr` and `frd` adapters at startup

**Exit criteria:**

- All v1 universe tickers ingested, unadjusted, pipeline-enriched
- Cross-source discrepancies flagged with confidence scores
- Data quality gating prevents anomalies from reaching downstream modules
- Both deployment configurations (Duo Wealth, DataDuo) registerable correctly

**Total Phase 1A:** 5-8 weeks realistic.

**Dependencies:** PostgreSQL 16 + Parquet + DuckDB (per ADR-001), Python data stack, public-domain source access (no auth required), personal-license access for FRD historical and IBKR APIs (Duo Wealth deployment only).
**Feeds into:** Everything — no other module can be built without M1.

-----

### >>> FIRST REPRODUCIBLE RESULT MILESTONE <<<

Before Phase 1B begins, validate that the data foundation is reproducible end-to-end on a single ticker:

- AAPL ingested via the Stooq adapter through M1
- Unadjusted, pipeline-enriched, written to research store with full provenance
- Re-running the ingest from a recorded data manifest produces materially identical research-tier output (same adjustment factors, same provenance lineage, same row counts)
- Lifecycle registry returns correct point-in-time membership for AAPL across its full history

This is a data-layer reproducibility gate. The broader M1 → M2 → M4 → M5 → M6 reproducibility loop (full strategy/backtest/scorecard/manifest cycle) is realized at the Tier 1 milestone after Phase 1C; this earlier milestone proves the substrate is sound before strategy and backtest layers build on it. If single-ticker data flow doesn't reproduce cleanly, scaling to strategy work is premature.

-----

## PHASE 1B: Strategy & Backtest Core

**Goal:** Build M2 (Strategy Factory), M3 (Feature Registry), and M4 (Backtest Engine). The system can define strategies and run backtests. Reference strategy suite registered for Phase B validation.

**Modules:** M2, M3, M4
**Contracts to define:**

- `strategy-contract.md` — must be defined before M2 implementation
  **Research to resolve first:**
- VectorBT open source capabilities vs. needs (do we need Pro?) → may update ADR-001
- Compute profiling — can RTX 3090 handle target parameter sweeps?

**Work:**

*M3 — Feature Registry (build alongside or slightly before M2):*

- Write `modules/m03-feature-registry.md` spec
- Build feature module structure (standardized function signatures, naming convention)
- Implement initial features: SMA, EMA, RSI, ATR, momentum (12-1), volatility
- Feature versioning via Git (convention-based initially)

*M2 — Strategy Factory:*

- Write `modules/m02-strategy-factory.md` spec
- Define and write `contracts/strategy-contract.md`
- Build strategy base class / interface (Python dataclass or abstract class)
- Build strategy metadata schema (YAML template with all mandatory fields)
- Build parameter manager (tunable vs. fixed, ranges, defaults)
- Strategy versioning integration with Git
- Build one reference strategy to validate the interface works end-to-end. This should be intentionally simple — a basic ETF momentum or moving-average crossover strategy is ideal. The goal is to validate plumbing, not prove the system can find alpha. Ambitious strategies come after the infrastructure is trusted.

*M4 — Backtest Engine:*

- Write `modules/m04-backtest-engine.md` spec
- VectorBT integration layer (strategy contract → VectorBT signals → results)
- Cost modeling (commission schedules per broker, slippage model)
- Walk-forward engine (rolling train/test windows)
- Parameter sensitivity analyzer (sweep parameters, generate heatmaps)
- Monte Carlo simulator (reshuffle trade sequences, estimate DD distributions)
- Regime splitter (segment backtest by tagged market conditions — manual tags initially)
- Characterization profile generator (full output as defined in blueprint)
- Tests: look-ahead bias prevention, cost model accuracy, walk-forward correctness

*Reference Strategy Suite — registered for Phase B validation:*

- Design standardized reference suite (initial target: 5-8 strategies) covering long-only, long-short, momentum, mean-reversion, moving-average crossover, volatility-targeted sizing
- Strategies are simple and interpretable — differences across warehouses must be attributable to data, not strategy complexity
- All conform to the Strategy Contract and are versioned per M2; suite version pinned per Phase B validation run
- Register suite in `strategies/reference/`
- Build comparative scorecard infrastructure: per-warehouse scorecard generation and cross-warehouse delta computation (consumed by Phase B; depends on M5's scorecard format being settled)

**Dependencies:** M1 (data to backtest against), VectorBT (installed and configured)
**Feeds into:** M5 (needs backtest output to design grading against), M6 (needs runs to track), Phase B (reference suite is the unit of warehouse comparison)

**Exit criteria:**

- Can define a strategy using the strategy contract
- Can run that strategy through a backtest and get a full characterization profile
- Walk-forward, parameter sensitivity, and Monte Carlo all produce results
- Cost modeling reflects realistic IBKR commission/slippage
- Reference strategy demonstrates the full pipeline end-to-end
- Reference suite registered and versioned, ready for Phase B build-out

**Estimated scope:** 3-5 focused sessions

-----

## PHASE 1C: Evaluation & Tracking

**Goal:** Build M5 (Metrics & Grading) and M6 (Experiment Tracking). The system can evaluate strategies consistently and reproduce any run.

**Modules:** M5, M6
**Contracts to define:**

- `scorecard-format.md` — must be defined before M5 implementation
- `run-manifest-format.md` — must be defined before M6 implementation

**Work:**

*M5 — Metrics & Grading:*

- Write `modules/m05-metrics-grading.md` spec
- Define and write `contracts/scorecard-format.md`
- Build metric calculators (Sharpe, Sortino, Calmar, DD, win rate, profit factor, etc.)
- Build scorecard generator (standardized report format)
- Build cross-strategy comparator (correlation analysis, ranking)
- Statistical significance engine (confidence intervals, minimum evidence thresholds)
- Benchmark comparison (vs. buy-and-hold, vs. factor ETFs)
- Integrate with pyfolio/QuantStats for calculation primitives

*M6 — Experiment Tracking:*

- Write `modules/m06-experiment-tracking.md` spec
- Define and write `contracts/run-manifest-format.md`
- Build run manifest capture (auto-record git commit, strategy version, parameters, data snapshot, seeds, timestamp, environment)
- Build run archive (manifests in PostgreSQL per ADR-001, queryable)
- Build reproducibility verification (re-run from manifest, compare results)
- Retroactively capture manifests for any backtests already run in Phase 1B

**Dependencies:** M4 (backtest output to evaluate), Git (version tracking)
**Feeds into:** All future pipeline stages use the same scorecard and tracking

**Exit criteria:**

- Every backtest run automatically generates a scorecard and a run manifest
- Can compare two strategies side-by-side using standardized metrics
- Can reproduce a previous backtest run from its manifest and get materially identical results. "Materially identical" means core metrics (total return, Sharpe, max drawdown, trade count) match exactly or within a defined tolerance (e.g., <0.01% variance). Minor floating-point differences across environments are acceptable — meaningful metric divergence is not. Define the tolerance threshold in the run manifest contract.
- Statistical significance is assessed — system flags when results might be noise

**Estimated scope:** 2-3 focused sessions

-----

### >>> TIER 1 MILESTONE <<<

At this point you have a working research workbench:

- Ingest and serve clean market data
- Define strategies with standardized contracts and metadata
- Backtest with realistic assumptions and full characterization
- Evaluate with consistent metrics and statistical rigor
- Track and reproduce every run

This alone is useful. You can research and validate strategy ideas here. Everything after this is the validation pipeline (Phase B), capability domain expansion (Phase C), tournament and paper infrastructure (Phase 2), live deployment (Phase 3), and intelligence layer (Phase 4).

-----

## PHASE B: Three-Warehouse Validation

**Goal:** Validate that the pipeline produces trustworthy output by triangulating three independently-sourced warehouses and measuring cross-warehouse scorecard deltas. Per `contracts/validation-protocol.md`.

**What this phase produces:**

- Empirically-measured tolerance thresholds for cross-warehouse scorecard deltas (filled into the TBD rows of `contracts/validation-protocol.md`)
- A trust anchor for DataDuo's Comparative Truth Engine — the A-vs-B delta itself, not a guess about it
- Evidence that the pipeline's source-agnostic claim holds in practice

**Warehouse build-out:**

- **Warehouse A** (`warehouse_dataduo`) — free sources (Stooq + yfinance gap-fill), pipeline-enriched. Built on both deployment configurations (Duo-Wealth-side variant uses IBKR forward; DataDuo-side variant uses ongoing free-source ingestion); both must produce identical enrichment output.
- **Warehouse B** (`warehouse_duo_wealth`) — FRD historical (one-time bootstrap through the FRD adapter, unadjust, re-enrich) plus IBKR forward, pipeline-enriched. After bootstrap, B is maintained forward by IBKR alone.
- **Warehouse C** (`warehouse_test`) — FRD historical plus ongoing FRD updates via the one-month free window, pipeline-enriched. Bounded by FRD update access.

**Work:**

- Build Warehouse A on both deployment configurations; verify identical enrichment output across variants
- Bootstrap Warehouse B from FRD historical (one-time pull through the FRD adapter)
- Stand up Warehouse C with FRD historical + recurring update-window pulls
- Run the reference strategy suite (built in Phase 1B) across all three warehouses
- Generate scorecards per warehouse via M5
- Compute cross-warehouse deltas (A-vs-B, A-vs-C, B-vs-C)
- Record measured thresholds in `contracts/validation-protocol.md`'s tolerance table
- Begin paper-trading lanes per warehouse for strategies whose deltas fall within tolerance (M9 work, sequenced into Phase 2A)

**Phase exit and warehouse lifetime transition:**

Phase B exit is the moment Warehouses A and B transition from validation arms to permanent operation:

- **Warehouse A continues running indefinitely** as DataDuo's product feed. The Comparative Truth Engine consumes ongoing A-vs-B deltas as new dates roll in. A is not dismantled at Phase B exit — its persistent operation is what makes the comparative claim a live trust anchor rather than a frozen Phase B snapshot.
- **Warehouse B becomes Duo Wealth's permanent production research warehouse.** All Phase C, Phase 2, Phase 3, and Phase 4 work runs against B. FRD is no longer in B's operational loop.
- **Warehouse C continues only as long as FRD update access continues.** C is dismantled when FRD update access ends. Loss of FRD updates does not affect A or B.

**Dependencies:** Phase 1 complete (pipeline operational, reference suite defined, M5 scorecard format settled, M6 manifest capture working)
**Feeds into:** Phase C (runs against W2), Phase 2A (warehouse-aware paper trading), DataDuo Launch (Comparative Truth Engine deliverable)

**Estimated scope:** 4-8 weeks (calibrated against actual measurement runtime needs and FRD update window cadence)

-----

## PHASE C: Capability Domain Expansion

**Goal:** Expand the pipeline's capability domain coverage beyond what Phase 1A's foundation covers. Phase C is not a feature-group rollout — each addition is a capability domain the pipeline now covers, available to both deployments through the same enrichment logic.

**Runs against Warehouse B (Duo Wealth's permanent production warehouse).** After Phase B exit, B is Duo Wealth's research warehouse for all subsequent work. Phase C's enrichment additions are validated against B and made available to DataDuo's deployment configuration on the same release cadence.

**Capability domains to expand:**

- **Short interest** — FINRA biweekly short interest reports
- **ETF/fund holdings (general)** — N-PORT filings beyond the index-reconstruction use already covered in Phase 1A
- **Institutional holdings** — 13F filings
- **Insider activity** — SEC Forms 3, 4, 5
- **Direct macro primary sources** — Treasury Fiscal Data (debt, federal financials), BLS (employment, CPI), BEA (GDP, regional accounts), with FRED/ALFRED demoted from primary to reconciliation cross-check per ADR-003

**Work per domain:**

- Source ingestion adapter (mirrors price source adapter pattern, adapted for non-price domain)
- Domain-specific normalization to canonical schema
- Provenance metadata per `contracts/data-provenance-schema.md`
- Reconciliation rules where multiple sources cover overlapping ground (e.g., FRED vs Treasury for debt-related macro)
- Per-domain test fixtures
- Module spec documentation

**Dependencies:** Phase B complete (W2 in permanent operation, W1 feeding Comparative Truth Engine)
**Feeds into:** Strategy research (broader signal universe in M3), DataDuo Enrichment API surface area

**Estimated scope:** Variable per domain — 1-3 weeks each, can be parallelized across domains.

-----

## PHASE 2A: Tournament & Paper Trading

**Goal:** Build M8 (Tournament Arena) and M9 (Paper Trading Bridge). Strategies can compete head-to-head and validate against live market conditions. Promotion through these stages follows `contracts/validation-protocol.md` and `contracts/promotion-demotion-rules.md`.

**Modules:** M8, M9
**Contracts to define:**

- `promotion-demotion-rules.md` — canonical gate criteria
- `broker-abstraction.md` — internal interface for broker interaction
  **Research to resolve first:**
- ib_insync replacement evaluation (Open Question #2)
- Alpaca IEX data limitation impact
- Tournament duration thresholds (will need real data, start with hypothesis)

**Work:**

*M8 — Tournament Arena:*

- Write `modules/m08-tournament-arena.md` spec
- Define and write `contracts/promotion-demotion-rules.md`
- Build tournament runner (N strategies, identical capital, same data feed)
- Multi-dimensional scoring engine (not just returns — drawdown, stability, correlation contribution, behavior vs. expectation)
- Promotion/demotion logic (applies rules from contract; respects Phase B cross-warehouse gate)
- Tournament history storage
- Correlation monitor (flag when entrants are too similar)
- Integrate with Alpaca paper trading API for execution simulation

*M9 — Paper Trading Bridge:*

- Write `modules/m09-paper-trading.md` spec
- Define and write `contracts/broker-abstraction.md`
- Build broker abstraction layer (insulate from specific API)
- Build paper execution layer (IBKR paper or Alpaca)
- Fill and slippage tracker (actual vs. modeled)
- Divergence detector (paper performance vs. backtest characterization, evaluated per warehouse lane)
- Implementation shortfall calculator
- Paper twin runner (continues paper alongside live — infrastructure only, live comes in Phase 3)
- Per-warehouse paper lanes — strategies that passed Phase B run paper trading in each warehouse simultaneously; consistency across lanes is a live-deployment prerequisite

**Dependencies:** M1 (live/delayed data feed), M2 (strategy definitions), M5 (scoring), M6 (run tracking), broker API, Phase B (cross-warehouse promotion gate)
**Feeds into:** M12 (live deployment), M10 (graveyard receives killed strategies)

**Exit criteria:**

- Can run multiple strategies in a tournament with automated scoring
- Can promote a tournament winner to paper trading
- Paper trading executes via broker API with tracked fills
- Divergence between paper and backtest is measured and flagged per warehouse lane
- Promotion/demotion rules are enforced from the canonical contract

**Estimated scope:** 3-5 focused sessions

-----

## PHASE 2B: Graveyard & Governance

**Goal:** Build M10 (Graveyard) and M7 (Research Governance). Institutional memory and idea intake discipline.

**Modules:** M10, M7
**Contracts to define:**

- `kill-record-format.md`

**Work:**

*M10 — Graveyard & Archive:*

- Write `modules/m10-graveyard.md` spec
- Define and write `contracts/kill-record-format.md`
- Build kill record storage (strategy ID, scorecard, manifest, reason, failure tag, lineage)
- Searchable archive (query by edge type, failure pattern, date, lineage)
- Strategy lineage tracking (link child strategies to parents)

*M7 — Research Governance:*

- Write `modules/m07-research-governance.md` spec
- Formalize idea intake template (already exists as markdown — integrate into workflow)
- Build idea log (accepted/rejected proposals with rationale)
- Integrate graveyard search into intake process (check before proposing)

**Dependencies:** M5 (scorecards for kill records), M6 (manifests for kill records)
**Feeds into:** Strategy Factory (prevents redundant work), future failure analysis

**Exit criteria:**

- Every killed strategy has a structured kill record
- Can search graveyard by failure pattern, edge type, strategy lineage
- Idea intake process is documented and integrated (even if lightweight)

**Estimated scope:** 1-2 focused sessions

-----

### >>> TIER 2 MILESTONE <<<

Full validation pipeline operational:

- Strategies go from idea → intake → define → backtest → characterize → tournament → paper → validated
- Failed strategies are archived with structured kill records
- No manual gaps in the pipeline — every transition has defined criteria

-----

## PHASE 3A: Portfolio & Risk Engine

**Goal:** Build M11. The system can construct portfolios, manage allocation, and enforce risk constraints across multiple strategies.

**Modules:** M11
**Research to resolve first:**

- Circuit breaker multipliers
- Rebalancing frequency and approach

**Work:**

- Write `modules/m11-portfolio-risk.md` spec
- Position sizing framework
- Volatility targeting
- Strategy allocation (confidence-weighted)
- Exposure controls (asset, sector, theme caps)
- Correlation-aware scaling
- Margin and cash constraints
- Rebalance logic
- Portfolio-level circuit breaker (separate from per-strategy)
- Strategy roster manager (active, probation, benched, development, retired)

**Dependencies:** M5 (strategy scorecards, correlation data), M2 (strategy metadata)
**Feeds into:** M12 (allocation instructions for live execution)

**Exit criteria:**

- Can take N qualified strategies and produce a portfolio allocation
- Correlation analysis prevents hidden concentration
- Portfolio-level drawdown protection defined and tested
- Roster management tracks strategy tiers

**Estimated scope:** 2-3 focused sessions

-----

## PHASE 3B: Live Deployment & Alerts

**Goal:** Build M12 (Live Deployment) and M13 (Alerts). Real capital deployed with automated protection and monitoring.

**Modules:** M12, M13

**Work:**

*M12 — Live Deployment:*

- Write `modules/m12-live-deployment.md` spec
- Order execution via broker abstraction (built in Phase 2A)
- Position and P&L monitoring
- Strategy-level circuit breakers (auto-pause on DD threshold)
- Performance vs. characterization tracking
- Execution quality monitoring
- Cash management and settlement

*M13 — Alerts:*

- Write `modules/m13-alerts.md` spec
- Define and write `contracts/alert-event-schema.md`
- Build alert event pipeline (modules emit, alert system routes)
- Circuit breaker alerts
- Divergence alerts
- Data quality alerts
- Execution failure alerts
- Delivery via Teams/Telegram (reuse MIC3 dispatch pattern)

**Dependencies:** M11 (allocation, risk limits), M9 (broker abstraction), M1 (data feeds), M5 (performance tracking)
**Feeds into:** Your real money working in the market

**Exit criteria:**

- Can deploy a strategy live with automated order execution
- Circuit breakers pause strategies automatically on threshold breach
- Paper twin runs alongside live for ongoing comparison
- Alert system notifies on all critical events
- You are confident the protection layer works before capital is at risk

**CRITICAL: Completing this phase means the infrastructure is ready — it does NOT mean capital is deployed.** Activating live trading with real money requires explicit human approval, separate from phase completion. The system is built to execute, but the decision to turn it on is always yours, never automated. No strategy goes live without you deliberately flipping the switch after reviewing the full pipeline output.

**Estimated scope:** 3-5 focused sessions

-----

### >>> TIER 3 MILESTONE <<<

The Duo Wealth incubator is fully operational:

- Idea → backtest → tournament → paper → live with real capital
- Portfolio-level risk management across multiple strategies
- Automated circuit breakers and alerting
- Every run tracked and reproducible

-----

## PHASE 4: Intelligence Layer

**Goal:** Build M14 (Regime Monitor) and M15 (Adaptive Allocation). The system gets context-aware.

**Modules:** M14, M15
**Research to resolve first:**

- Regime detection approaches → `research/topics/regime-detection.md`

**Work:**

*M14 — Regime Monitor:*

- Write `modules/m14-regime-monitor.md` spec
- Regime classifier (start simple: VIX thresholds + trend indicators)
- Historical regime tagger (label past periods for backtest context)
- Regime change detector (real-time)
- Strategy-regime performance map

*M15 — Adaptive Allocation:*

- Write `modules/m15-adaptive-allocation.md` spec
- Regime-based roster recommendations (suggest to M11, M11 decides)
- Dynamic reweighting suggestions based on rolling performance + regime
- Graveyard intelligence (failure pattern recognition)

**Dependencies:** M1 (market data), M5 (performance data), M11 (portfolio engine — M15 suggests, M11 enforces)

**Exit criteria:**

- System classifies current market regime
- Backtest results are viewable by regime
- Adaptive allocation suggests (not forces) roster and weight changes
- M11 retains final authority over all risk decisions

**Estimated scope:** 2-4 focused sessions

-----

## DATADUO LAUNCH

**Parallel deployment track.** DataDuo can launch independently of Duo Wealth's Phase 2/3/4 work, once its prerequisites are met. DataDuo runs the same pipeline codebase as Duo Wealth (per ADR-003); what differs is the deployment configuration (cloud VPS, public-domain sources only, no FRD/IBKR adapters) and the surface area served (enrichment outputs, never prices).

**Prerequisites:**

- Phase B complete — Warehouse A is operational and the Comparative Truth Engine has measured A-vs-B deltas to publish
- Phase C complete to the desired launch surface area (does not require all domains; can launch with a subset and expand)
- IP attorney consultation complete — confirms ETF-holdings-as-universe-proxy and other served domains have a clean legal posture
- VPS infrastructure provisioned

**Three deliverables (per ADR-003 / Audit Finding 12):**

1. **Enrichment API.** Cloud-deployed pipeline serving universe membership history, corporate actions, fundamentals, short interest, holdings, insider activity, calendar, macro, lifecycle. Never serves prices. Authentication, rate limiting, billing as appropriate.

2. **Build-Your-Own-Warehouse methodology.** Public-facing documentation/guide teaching retail users how to construct a backtest-ready warehouse from free price sources enriched by DataDuo outputs. The configuration this methodology produces IS Warehouse A. Running W1 locally validates that the methodology actually works.

3. **Comparative Truth Engine.** Ongoing published comparison of free-data-plus-DataDuo-enrichment vs. FRD-assisted reference. Fed by Warehouse A and Warehouse B both running continuously, producing fresh A-vs-B scorecard deltas as new dates roll in. The honest accuracy delta is the trust anchor.

**Work:**

- VPS provisioning and deployment automation
- Adapter-registration enforcement (DataDuo refuses `ibkr` and `frd` adapters at startup)
- API design, auth, rate limiting, billing infrastructure
- Build-Your-Own-Warehouse methodology guide
- Comparative Truth Engine publication infrastructure (publishing cadence TBD — open question)
- Legal review and posture documentation

**Dependencies:** Phase B + targeted Phase C surface, IP attorney consultation
**Feeds into:** Public DataDuo product (parallel to Duo Wealth track)

**Estimated scope:** 4-8 weeks after prerequisites are met.

-----

## Backlog (Unscheduled)

Items that are valuable but not assigned to a phase yet:

- Graveyard failure pattern analytics (M10d) — automated pattern recognition across kill records
- Advanced regime models beyond simple VIX/trend classification
- Multi-asset expansion (options, futures) — requires strategy contract extension
- Dashboard / web UI for monitoring (currently all CLI/notebook)
- VectorBT Pro evaluation and potential upgrade
- Automated strategy generation / screening (ML-assisted idea generation)
- Tax-aware execution (wash sale avoidance, lot selection)
- Multi-account management (taxable + retirement IBKR accounts)
- Universe expansion beyond S&P 500 + S&P 400 (Russell 2000 via IWM, international, etc.)
- DataDuo subscription tier and pricing model design

-----

## Recently Completed

|Date      |Item                                |Notes                                                                                                                                |
|----------|------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------|
|2026-04-04|System blueprint v0.2.1             |Full end-state architecture defined                                                                                                  |
|2026-04-04|Documentation architecture plan v1.1|Docs structure + research layer defined                                                                                              |
|2026-04-04|This roadmap v1.0                   |Build sequence defined                                                                                                               |
|2026-04-04|Backtesting landscape research      |VectorBT, Backtrader, tournament concept                                                                                             |
|2026-04-09|ADR-001, ADR-002 accepted           |Storage architecture (PostgreSQL + Parquet + DuckDB) and data provider stack locked                                                  |
|2026-04-18|Data landscape review v2 + S&P 400/600 deep research|Multi-source landscape mapped; ETF-holdings reconstruction (MDY/IJR via N-PORT) confirmed for S&P 400/600 universe history|
|2026-04-19|Architectural audit                 |Two-deployment pipeline, three-warehouse validation, lifecycle registry, multi-source adapter pattern locked. ADR-003 accepted. Stage 1 deliverables (ADR-003 + 4 contracts + 4 research topics) committed.|
|2026-04-24|Blueprint v0.4 + roadmap v1.1 + knowledge architecture plan v1.2|Stage 2-4 of audit execution: governing documents updated to reflect locked architecture; warehouse framing refined to distinguish persistent / permanent / temporary lifetimes and FRD's bootstrap-vs-comparison roles|
|2026-04-25|Phase 1 build plan locked|Eleven-stage sequence committed to `research/topics/phase-1-build-plan.md`. Multi-source-from-the-start correction applied (vs single-ticker validation in audit's A2). 2005 coverage start locked. MDY/IJR sequenced after S&P 500 within Phase 1A-A1. Empirical source verification gate added before Stage 1 implementation. Stooq adjustment-state finding (fully adjusted, no separate raw series) drove reverse-adjustment-engine-before-price-ingestion sequencing.|

-----

## Blocked / Waiting

|Item                                  |Blocked by                              |Impact                                                                              |
|--------------------------------------|----------------------------------------|------------------------------------------------------------------------------------|
|ib_insync replacement                 |Needs research + evaluation             |Blocks Phase 2A broker abstraction design                                           |
|DataDuo IP attorney consultation      |Engagement of IP counsel                |Blocks DataDuo go-live (prerequisite per ADR-003 Revisit-If clause)                 |
|Phase B tolerance threshold seeding   |Phase B measurement runs                |Initial thresholds in `contracts/validation-protocol.md` remain TBD until measured  |

-----

*Document version: 1.1*
*Created: April 2026*
*Status: Active — defines build sequence and current priorities*
*Changelog v1.0.1: Clarified reference strategy in Phase 1B should be intentionally simple (validate plumbing, not alpha). Defined reproducibility as materially identical with tolerance threshold, not bit-identical. Added explicit human approval gate for live capital activation in Phase 3B.*
*Changelog v1.1: Phase 1A rewritten with universe-and-lifecycle-first sequencing per Audit Finding 14 — A1 (Universe and Lifecycle Foundation), A2 (Single-Ticker Price Pipeline via Stooq adapter), A3 (Scale and Multi-Source Coverage). Added First Reproducible Result Milestone between Phase 1A and 1B as data-layer reproducibility gate. Added reference strategy suite work items to Phase 1B (feeds Phase B validation per Finding 11). Added new Phase B (Three-Warehouse Validation) section between Tier 1 milestone and Phase 2A, with explicit warehouse lifetime transition at Phase B exit (A and B persistent, C temporary). Added new Phase C (Capability Domain Expansion) running against Warehouse B, reframed from "feature group additions" to "capability domain expansion" per Finding 3. Added DataDuo Launch as parallel deployment track with three deliverables and IP attorney prerequisite per Finding 12. Updated Phase 2A to reflect warehouse-aware paper lanes and Phase B promotion gate. Phase 0 marked COMPLETE. Removed settled open questions (data provider selection, S&P 400 constituency). Added DataDuo IP attorney consultation and Phase B tolerance threshold seeding to Blocked/Waiting. Recently Completed entries added for 2026-04-09 (ADR-001/002), 2026-04-18 (landscape review), 2026-04-19 (architectural audit + Stage 1), 2026-04-24 (Stage 2-4 of audit execution). Implements `audits/System_Audit_And_Documentation_Update_Plan_April_2026.md` Part 3 §Roadmap.*
