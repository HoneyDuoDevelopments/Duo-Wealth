# HoneyDuo Wealth — Roadmap

## Current Status

**Phase:** Pre-build — architecture and documentation complete, no code yet
**Last updated:** April 2026

-----

## Phase Overview

```
PHASE 0 ─── Project Setup & Research Capture ◀── YOU ARE HERE
    │
PHASE 1A ── Data Foundation
    │
PHASE 1B ── Strategy & Backtest Core
    │
PHASE 1C ── Evaluation & Tracking
    │
    ├────── MILESTONE: Can define a strategy, backtest it, get a scorecard,
    │       reproduce the run. Foundation is solid.
    │
PHASE 2A ── Tournament & Paper Trading
    │
PHASE 2B ── Graveyard & Governance
    │
    ├────── MILESTONE: Full validation pipeline. Strategies go from idea
    │       to paper-validated with no manual gaps.
    │
PHASE 3A ── Portfolio & Risk Engine
    │
PHASE 3B ── Live Deployment & Alerts
    │
    ├────── MILESTONE: Real capital deployed with automated protection.
    │
PHASE 4 ─── Intelligence Layer (Regime, Adaptive Allocation)
    │
    ├────── MILESTONE: System adapts to market conditions.
```

Why sub-phases within tiers: each sub-phase has a clear exit criteria and delivers something usable on its own. You can pause between 1A and 1B and still have a working data layer. You can run backtests after 1C without needing tournament infrastructure. Each phase is a stable plateau, not a cliff.

-----

## PHASE 0: Project Setup & Research Capture

**Goal:** Get the repo standing, docs committed, and capture research already done so nothing lives only in chat history.

**Work:**

- Create GitHub repo with full folder skeleton from docs architecture plan
- Commit `blueprint.md` (v0.2.1)
- Commit documentation architecture plan
- Commit this roadmap
- Create `ADR-000-template.md`
- Create `research/research-method.md` (template and evidence labels)
- Create `research/open-questions.md` (seed from blueprint open questions)
- Create `research/topics/backtesting-landscape.md` (capture findings from initial research session — VectorBT, Backtrader, QuantConnect, tournament concept, common failure modes)
- Create placeholder files for Phase 1 module specs and contracts (empty with header only)
- Write ADR-001 through ADR-004 (VectorBT, ib_insync provisional, MySQL, Python)

**Exit criteria:**

- Repo exists with full structure
- All existing knowledge captured in docs (nothing critical lives only in chat)
- Any future session can start by uploading blueprint + roadmap and be oriented in 2 minutes

**Estimated scope:** One focused session

-----

## PHASE 1A: Data Foundation

**Goal:** Build M1 (Data Layer) — the system can ingest, normalize, store, validate, and serve market data.

**Modules:** M1 (Data Layer)
**Contracts to define:** None yet (Data Layer is a provider, not a consumer of contracts)
**Research to resolve first:**

- Data provider selection (Open Question #1) — what providers, what resolution, what cost?
- Asset class scope for v1 (Open Question #5) — US equities and ETFs to start?

**Work:**

- Write `modules/m01-data-layer.md` spec
- Research and select data provider(s) → write `research/topics/data-providers.md` → ADR
- Build raw data ingestion (provider API → raw store in MySQL)
- Build canonical normalization layer (raw → unified schema)
- Build research-ready layer (adjusted prices, corporate actions, validation)
- Build universe manager (define and maintain instrument lists)
- Data quality validation checks (gap detection, stale data, suspicious values)
- Build internal data serving API (other modules query data through this, not direct DB)
- Tests: data integrity, corporate action handling, provider failover

**Dependencies:** MySQL (existing), chosen data provider API
**Feeds into:** Everything — no other module can be built without data to work on

**Exit criteria:**

- Can ingest daily OHLCV for a universe of US ETFs
- Data is stored in raw + canonical + research-ready tiers
- Quality validation catches known bad-data patterns
- Internal API serves clean, adjusted data to calling code
- Universe manager can define and filter instrument lists
- All of this is documented in the module spec

**Estimated scope:** 2-4 focused sessions

-----

## PHASE 1B: Strategy & Backtest Core

**Goal:** Build M2 (Strategy Factory), M3 (Feature Registry), and M4 (Backtest Engine). The system can define strategies and run backtests.

**Modules:** M2, M3, M4
**Contracts to define:**

- `strategy-contract.md` — must be defined before M2 implementation
  **Research to resolve first:**
- VectorBT open source capabilities vs. needs (do we need Pro?) → may update ADR-001
- Compute profiling (Open Question #6) — can RTX 3090 handle target parameter sweeps?

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

**Dependencies:** M1 (data to backtest against), VectorBT (installed and configured)
**Feeds into:** M5 (needs backtest output to design grading against), M6 (needs runs to track)

**Exit criteria:**

- Can define a strategy using the strategy contract
- Can run that strategy through a backtest and get a full characterization profile
- Walk-forward, parameter sensitivity, and Monte Carlo all produce results
- Cost modeling reflects realistic IBKR commission/slippage
- Reference strategy demonstrates the full pipeline end-to-end

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
- Build run archive (store manifests in MySQL, queryable)
- Build reproducibility verification (re-run from manifest, compare results)
- Retroactively capture manifests for any backtests already run in Phase 1B

**Dependencies:** M4 (backtest output to evaluate), Git (version tracking)
**Feeds into:** All future pipeline stages use the same scorecard and tracking

**Exit criteria:**

- Every backtest run automatically generates a scorecard and a run manifest
- Can compare two strategies side-by-side using standardized metrics
- Can reproduce a previous backtest run from its manifest and get materially identical results. “Materially identical” means core metrics (total return, Sharpe, max drawdown, trade count) match exactly or within a defined tolerance (e.g., <0.01% variance). Minor floating-point differences across environments are acceptable — meaningful metric divergence is not. Define the tolerance threshold in the run manifest contract.
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

This alone is useful. You can research and validate strategy ideas here. Everything after this is the validation pipeline, deployment infrastructure, and intelligence layer.

-----

## PHASE 2A: Tournament & Paper Trading

**Goal:** Build M8 (Tournament Arena) and M9 (Paper Trading Bridge). Strategies can compete head-to-head and validate against live market conditions.

**Modules:** M8, M9
**Contracts to define:**

- `promotion-demotion-rules.md` — canonical gate criteria
- `broker-abstraction.md` — internal interface for broker interaction
  **Research to resolve first:**
- ib_insync replacement evaluation (Open Question #2)
- Alpaca IEX data limitation impact (Open Question #7)
- Tournament duration thresholds (Open Question #3 — will need real data, start with hypothesis)

**Work:**

*M8 — Tournament Arena:*

- Write `modules/m08-tournament-arena.md` spec
- Define and write `contracts/promotion-demotion-rules.md`
- Build tournament runner (N strategies, identical capital, same data feed)
- Multi-dimensional scoring engine (not just returns — drawdown, stability, correlation contribution, behavior vs. expectation)
- Promotion/demotion logic (applies rules from contract)
- Tournament history storage
- Correlation monitor (flag when entrants are too similar)
- Integrate with Alpaca paper trading API for execution simulation

*M9 — Paper Trading Bridge:*

- Write `modules/m09-paper-trading.md` spec
- Define and write `contracts/broker-abstraction.md`
- Build broker abstraction layer (insulate from specific API)
- Build paper execution layer (IBKR paper or Alpaca)
- Fill and slippage tracker (actual vs. modeled)
- Divergence detector (paper performance vs. backtest characterization)
- Implementation shortfall calculator
- Paper twin runner (continues paper alongside live — infrastructure only, live comes in Phase 3)

**Dependencies:** M1 (live/delayed data feed), M2 (strategy definitions), M5 (scoring), M6 (run tracking), broker API
**Feeds into:** M12 (live deployment), M10 (graveyard receives killed strategies)

**Exit criteria:**

- Can run multiple strategies in a tournament with automated scoring
- Can promote a tournament winner to paper trading
- Paper trading executes via broker API with tracked fills
- Divergence between paper and backtest is measured and flagged
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

- Circuit breaker multipliers (Open Question #4)
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

The incubator is fully operational:

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

-----

## Recently Completed

|Date      |Item                                |Notes                                                          |
|----------|------------------------------------|---------------------------------------------------------------|
|2026-04-04|System blueprint v0.2.1             |Full end-state architecture defined                            |
|2026-04-04|Documentation architecture plan v1.1|Docs structure + research layer defined                        |
|2026-04-04|This roadmap                        |Build sequence defined                                         |
|2026-04-04|Backtesting landscape research      |VectorBT, Backtrader, tournament concept — needs formal capture|

-----

## Blocked / Waiting

|Item                   |Blocked by                 |Impact                                   |
|-----------------------|---------------------------|-----------------------------------------|
|Data provider selection|Needs research session     |Blocks Phase 1A                          |
|ib_insync replacement  |Needs research + evaluation|Blocks Phase 2A broker abstraction design|

-----

*Document version: 1.0.1*
*Created: April 2026*
*Status: Active — defines build sequence and current priorities*
*Changelog v1.0.1: Clarified reference strategy in Phase 1B should be intentionally simple (validate plumbing, not alpha). Defined reproducibility as materially identical with tolerance threshold, not bit-identical. Added explicit human approval gate for live capital activation in Phase 3B.*