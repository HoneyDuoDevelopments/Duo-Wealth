# HoneyDuo Wealth — Strategy Incubator Blueprint v0.2

## What This Document Is

This is the complete end-state definition of the Strategy Incubator — everything the system will eventually contain when fully realized. Not everything here gets built immediately. But everything here is architecturally defined now so that future work happens against stable boundaries.

Every module listed here belongs in the system. Modules are tagged with an architectural tier to distinguish between “must be defined and built early” and “must be defined now, built later.”

-----

## System Purpose

A modular, strategy-agnostic workbench for building, testing, validating, and deploying algorithmic trading strategies. This is not a trading bot — it is the operating system that produces, evaluates, manages, and retires trading bots.

Designed to be a long-horizon tool: extensible, auditable, reproducible, and structured for AI-assisted development across many sessions with minimal context reload.

-----

## Architectural Principles

These are non-negotiable design constraints validated by field research across LEAN, NautilusTrader, QSTrader, pysystemtrade, and practitioner accounts. They apply to every module and every implementation decision. Violating these creates the failure modes that kill solo quant systems.

**1. Backtest-to-live code parity is mandatory.**
Strategy code must be identical between research and production. No separate codepaths for backtesting and live trading. The system achieves this through the strategy contract (M2) and broker abstraction interface — strategy logic is decoupled from data source and execution venue. Swapping from historical data to live data, or from paper to real execution, changes the adapter, never the strategy. This is the single most regretted architectural decision when violated.

**2. Modular monolith, not microservices.**
The system is a single deployable Python application with well-separated internal modules. No Docker orchestration, no distributed networking, no containerized microservices. The operational overhead of microservices vastly outweighs any benefit for a solo builder. Module boundaries are enforced by clean interfaces and contracts, not by network calls.

**3. Data quality validation is first-class.**
Data validation is not an afterthought buried inside the data layer — it is a critical subsystem with its own checks, alerts, and failure modes. Bad data silently corrupts every downstream result. The system must validate on ingestion (gap detection, outlier flagging, volume anomalies, timestamp validation, cross-source comparison) and alert on any anomaly before it reaches the backtest engine or live trading.

**4. Transaction cost modeling must be conservative by default.**
Cost models default to overestimating commissions, slippage, and market impact rather than underestimating them. Ignoring or underestimating costs can slash realistic returns by 50%+ versus backtest results. Cost modeling is a pluggable, first-class component of the backtest engine — not an optional parameter you can forget to set.

**5. System health monitoring is as important as trading alerts.**
The alert system (M13) covers not just trading events but system health: data staleness, broker API connectivity, position reconciliation between internal state and broker state, scheduled job failures, and experiment tracking anomalies. A system that trades correctly but fails silently when infrastructure breaks is dangerous.

**6. Regime intelligence starts simple.**
Volatility-scaled position sizing (inversely sizing positions with current volatility) captures the majority of regime-adaptive benefit. HMM, ML classifiers, and complex regime models are Phase 4 features — they provide diminishing returns and increasing overfit risk. Start with VIX thresholds and realized volatility percentile rankings. Extend only when simple approaches demonstrably fail.

**7. Core loop before intelligence layer.**
The system must be able to run the full cycle — data → define → backtest → evaluate → paper trade → deploy — before tournament, regime, and adaptive allocation features are built. Every layer earns its place by proving the layer below it works. The incubator is the product, not the strategies — but a beautiful empty pipeline is worthless. Run a real strategy through Phase 1 as soon as possible.

**8. Portfolio construction rewards simplicity.**
Equal risk weights are surprisingly hard to beat. Start with volatility-normalized equal weighting and handcrafting (Carver’s method) before implementing optimization. Mean-variance optimization is notoriously unstable. Half-Kelly or quarter-Kelly as a leverage ceiling, never as a precise allocation tool. Sophisticated portfolio optimization is a Phase 4 concern.

-----

## Architectural Tiers

Every module is assigned a tier. This is NOT a build order — it’s a dependency and criticality classification.

**Tier 1 — Foundation:** Must exist before anything else works. These are load-bearing walls.
**Tier 2 — Pipeline:** The validation and promotion pipeline. Depends on Tier 1. This is where strategies get tested and qualified.
**Tier 3 — Operations:** Live deployment and protection. Depends on Tier 1 + 2. This is where real capital enters.
**Tier 4 — Intelligence:** Optimization and adaptation. Depends on everything below. Makes the system smarter over time but the system functions without it.

-----

## System Tree

```
STRATEGY INCUBATOR
│
├── TIER 1: FOUNDATION
│   ├── M1  Data Layer
│   │   ├── M1a  Raw Data Store (immutable vendor payloads)
│   │   ├── M1b  Canonical Store (normalized, unified schema)
│   │   ├── M1c  Research Store (adjusted, validated, universe-filtered)
│   │   ├── M1d  Universe Manager (instrument lists, filters, membership rules)
│   │   └── M1e  Data Quality Validator (gap detection, outlier flagging, stale data,
│   │            volume anomalies, cross-source comparison, corporate action verification,
│   │            alerts on any anomaly before data reaches downstream modules)
│   │
│   ├── M2  Strategy Factory
│   │   ├── M2a  Strategy Contract (interface definition all strategies must follow)
│   │   ├── M2b  Strategy Metadata Schema (hypothesis, edge source, regime expectations, failure modes)
│   │   ├── M2c  Parameter Manager (tunable vs fixed, ranges, defaults)
│   │   └── M2d  Strategy Versioning (every change tracked, linked to runs)
│   │
│   ├── M3  Feature & Signal Registry
│   │   ├── M3a  Feature Definitions (reusable signals: momentum, SMA, ATR, vol, etc.)
│   │   ├── M3b  Feature Versioning (changes to feature logic tracked independently)
│   │   └── M3c  Feature Dependency Map (which strategies use which features)
│   │
│   ├── M4  Backtest Engine
│   │   ├── M4a  Simulation Core (VectorBT integration, event processing)
│   │   ├── M4b  Cost Modeling (commissions, slippage, market impact per broker/instrument)
│   │   ├── M4c  Walk-Forward Engine (rolling train/test windows)
│   │   ├── M4d  Parameter Sensitivity Analyzer (±N% sweeps, heatmaps)
│   │   ├── M4e  Monte Carlo Simulator (trade sequence reshuffling, drawdown distributions)
│   │   └── M4f  Regime Splitter (segment backtests by market condition)
│   │
│   ├── M5  Metrics & Grading System
│   │   ├── M5a  Metric Calculators (Sharpe, Sortino, Calmar, DD, win rate, profit factor, etc.)
│   │   ├── M5b  Strategy Scorecard Generator (standardized report, same format everywhere)
│   │   ├── M5c  Cross-Strategy Comparator (correlation, ranking, overlap analysis)
│   │   ├── M5d  Statistical Significance Engine (confidence intervals, minimum evidence thresholds)
│   │   └── M5e  Benchmark Comparison (vs buy-and-hold, vs factor ETFs, vs relevant index)
│   │
│   └── M6  Experiment Tracking & Reproducibility
│       ├── M6a  Run Manifest (git commit, strategy version, feature version, parameter set,
│       │         data snapshot, universe version, cost model version, random seeds, timestamp)
│       ├── M6b  Run Archive (every backtest/tournament/paper run stored with full manifest)
│       └── M6c  Reproducibility Verification (re-run from manifest, compare results)
│
├── TIER 2: VALIDATION PIPELINE
│   ├── M7  Research Governance
│   │   ├── M7a  Idea Intake Template (hypothesis, edge source, data needs, failure modes,
│   │   │         benchmark, falsification criteria)
│   │   └── M7b  Idea Log (all proposed strategies, accepted or rejected, with rationale)
│   │
│   ├── M8  Tournament Arena
│   │   ├── M8a  Tournament Runner (N strategies, identical capital, same data feed)
│   │   ├── M8b  Scoring Engine (multi-dimensional: return, drawdown, stability,
│   │   │         implementation shortfall, correlation contribution, behavior vs expectation)
│   │   ├── M8c  Promotion/Demotion Rules (formal criteria, not vibes)
│   │   ├── M8d  Tournament History (full record of every tournament cohort and outcome)
│   │   └── M8e  Correlation Monitor (flag when entrants are too correlated)
│   │
│   ├── M9  Paper Trading Bridge
│   │   ├── M9a  Paper Execution Layer (broker paper API — see dependency note on ib_insync)
│   │   ├── M9b  Fill & Slippage Tracker (actual vs modeled execution quality)
│   │   ├── M9c  Divergence Detector (paper performance vs backtest characterization)
│   │   ├── M9d  Implementation Shortfall Calculator (theoretical vs actual)
│   │   └── M9e  Paper Twin Runner (continues paper execution alongside live for comparison)
│   │
│   └── M10 Graveyard & Archive
│       ├── M10a Kill Record (strategy ID, full scorecard at time of death, kill reason, failure pattern tag)
│       ├── M10b Searchable Archive (before building new strategy, check for similar prior failures)
│       ├── M10c Strategy Lineage Tracker (Strategy B is a child of Strategy A — link them)
│       └── M10d Failure Pattern Analytics (what categories of strategies keep failing? why?)
│
├── TIER 3: LIVE OPERATIONS
│   ├── M11 Portfolio & Risk Engine
│   │   ├── M11a Position Sizing (per-strategy, per-trade)
│   │   ├── M11b Volatility Targeting (normalize risk contribution across strategies)
│   │   ├── M11c Strategy Allocation (capital weighting by confidence, risk-adjusted return, track record)
│   │   ├── M11d Exposure Controls (caps by asset, sector, theme, strategy)
│   │   ├── M11e Correlation-Aware Scaling (highly correlated strategies share allocation bucket)
│   │   ├── M11f Margin & Cash Constraints (available capital, reserve requirements)
│   │   ├── M11g Rebalance Logic (frequency, drift thresholds, triggers)
│   │   ├── M11h Portfolio-Level Circuit Breaker (total portfolio drawdown kill-switch,
│   │   │         not just per-strategy)
│   │   └── M11i Strategy Roster Manager (active, probation, benched, development, retired tiers)
│   │
│   ├── M12 Live Deployment Manager
│   │   ├── M12a Order Execution (broker API integration — IBKR, with ib_insync flagged provisional)
│   │   ├── M12b Position & P&L Monitoring (real-time tracking)
│   │   ├── M12c Strategy-Level Circuit Breakers (auto-pause on DD threshold breach)
│   │   ├── M12d Performance vs Characterization Tracker (is live matching backtest/paper profile?)
│   │   ├── M12e Execution Quality Monitor (slippage, fill rates, timing)
│   │   └── M12f Cash Management & Settlement Tracking
│   │
│   └── M13 Alert & Notification System
│       ├── M13a Circuit Breaker Alerts (strategy or portfolio level pause triggered)
│       ├── M13b Divergence Alerts (live vs paper/backtest mismatch)
│       ├── M13c Data Quality Alerts (gaps, stale feeds, provider outage)
│       ├── M13d Tournament Event Alerts (promotion, demotion, cohort results)
│       ├── M13e Execution Failure Alerts (order rejected, API error, connectivity)
│       ├── M13f Regime Change Alerts
│       └── M13g Delivery Layer (Teams/Telegram/email — reuses MIC3 dispatch pattern)
│
└── TIER 4: INTELLIGENCE & ADAPTATION
    ├── M14 Regime Monitor
    │   ├── M14a Regime Classifier (bull, bear, sideways, crisis, high-vol, low-vol)
    │   ├── M14b Historical Regime Tagger (label past periods for backtest context)
    │   ├── M14c Regime Change Detector (real-time shift identification)
    │   └── M14d Strategy-Regime Map (expected performance per strategy per regime)
    │
    └── M15 Adaptive Allocation
        ├── M15a Regime-Based Rotation (tilt active roster toward regime-suited strategies)
        ├── M15b Dynamic Reweighting (adjust allocation based on rolling performance + regime)
        └── M15c Graveyard Intelligence (failure pattern recognition informing future strategy design)
```

-----

## Module Detail

### M1: Data Layer

**Tier:** 1 — Foundation
**What it does:** Ingests, normalizes, stores, validates, and serves all market data. Single source of truth for the entire system.

**Internal structure (logical tiers — can be one system with stage tags initially):**

- **Raw store:** Original vendor payloads, immutable, timestamped, provider-tagged. Never modified after ingestion. Enables auditability and vendor switching.
- **Canonical store:** Unified schema across all providers. Timestamps normalized, fields standardized. This is what modules query against.
- **Research store:** Adjusted for splits/dividends, validated, filtered by universe rules, corporate actions resolved. This is what backtests actually run on.

**Responsibilities:**

- Ingest OHLCV from multiple providers
- Handle corporate actions (splits, dividends, delistings, mergers, spinoffs)
- Data quality validation — flag gaps, bad ticks, stale data, suspiciously perfect data
- Support multiple timeframes (daily, hourly, minute — as needed)
- Universe management — define, maintain, and version lists of tradeable instruments
- Provider abstraction — switching from Yahoo Finance to Polygon shouldn’t require rewriting strategies
- Data snapshot versioning — tie every backtest run to an exact data state

**Depends on:** External providers (Yahoo Finance free tier, Alpaca free tier, IBKR market data, potentially Polygon/Tiingo if budget allows)
**Feeds into:** Every other module
**Tech:** Python, MySQL (existing Honey Duo infra), pandas for in-memory ops
**Key risk:** Silent data corruption. A bad split adjustment or missing dividend will make backtests lie. Validation checks are not optional.

-----

### M2: Strategy Factory

**Tier:** 1 — Foundation
**What it does:** Provides the standardized contract that all strategies must follow, plus metadata, versioning, and parameter management.

**Strategy Contract — every strategy must define:**

- Universe filter (what instruments does this trade?)
- Entry rules (what triggers a buy/short?)
- Exit rules (what triggers a close?)
- Position sizing rules (how much per trade?)
- Risk parameters (stop loss, max position, max drawdown tolerance)
- Required data frequency (daily, hourly, etc.)
- Required features (references to Feature Registry)
- Cost assumptions (expected commission, slippage model)
- Supported execution style (market orders, limit orders, MOC, etc.)

**Strategy Metadata — mandatory structured fields:**

- Hypothesis (what are we testing?)
- Expected source of edge (what inefficiency does this exploit?)
- Why this edge should persist (why hasn’t it been arbitraged away?)
- Expected holding period
- Expected turnover
- Expected best regime
- Expected worst regime
- Known failure modes
- Benchmark to beat (specific: “SPY buy-and-hold” or “AVUV” not “the market”)
- Capacity assumptions (at what capital level does this stop working?)
- Implementation risks (execution, data, timing)
- Falsification criteria (what result would prove this doesn’t work?)

**Depends on:** Data Layer (universe definitions, data schemas), Feature Registry (feature references)
**Feeds into:** Backtest Engine, Tournament, Paper Trading, Live Deployment
**Tech:** Python classes/dataclasses, YAML/JSON for metadata, Git for versioning
**Key risk:** Too rigid = can’t express complex strategies. Too loose = no standardization. Start with the minimum contract that covers ETF rotation and factor strategies. Extend when a real strategy needs it.

-----

### M3: Feature & Signal Registry

**Tier:** 1 — Foundation
**What it does:** Central library of reusable, versioned signal/feature calculations that strategies reference instead of duplicating.

**Examples of registered features:**

- Price momentum (12-1 month)
- N-day SMA / EMA
- ATR(N)
- Rolling volume percentile
- Volatility (realized, N-day)
- RSI(N)
- Sector-relative z-score
- Drawdown from high

**Why this exists:**
Without a registry, two strategies using “20-day ATR” might calculate it slightly differently. Parameter drift and duplicated logic become invisible bugs. The registry ensures one definition, versioned, tested, referenced by name.

**Depends on:** Data Layer (price/volume data to compute features)
**Feeds into:** Strategy Factory (strategies reference features by name + version)
**Tech:** Python module with standardized function signatures, versioned via Git
**Key risk:** Premature over-engineering. Start as a well-organized Python module with naming conventions. Formalize the registry interface when you have 10+ features and need to manage it.

-----

### M4: Backtest Engine

**Tier:** 1 — Foundation
**What it does:** Runs strategies against historical data and produces full characterization profiles. First validation gate. Not pass/fail — it answers “how does this strategy behave?”

**Characterization Profile Output:**

- Returns: total, CAGR, monthly distribution
- Risk-adjusted: Sharpe, Sortino, Calmar, Omega
- Drawdown: max DD, max DD duration, DD distribution (Monte Carlo P50, P75, P95)
- Trade stats: count, win rate, profit factor, expectancy, avg win/loss, avg holding period
- Parameter sensitivity: heatmap of core metrics across ±20% parameter range
- Regime breakdown: performance per tagged regime (bull, bear, sideways, crisis)
- Correlation: to benchmark(s) and to other tested strategies
- Out-of-sample: in-sample vs out-of-sample comparison
- Walk-forward: rolling window performance stability
- Edge annotation: linked to strategy metadata hypothesis

**Gate Criteria (Backtest → Tournament):**

- Positive risk-adjusted return (Sharpe > 0.5 as starting threshold, adjustable)
- Max drawdown within strategy-defined tolerance
- Parameter sensitivity passes — graceful degradation, not cliff
- Minimum evidence threshold: based on trade count, holding period, exposure time, and regime coverage (not a universal “100 trades” rule — slower strategies evaluated by observation length and independent bets)
- Out-of-sample performance within reasonable range of in-sample
- Strategy metadata complete — hypothesis, edge source, falsification criteria documented
- Economic rationale passes sniff test — can you explain why this edge should persist?

**Depends on:** Data Layer (research store), Strategy Factory (strategy definitions), Feature Registry, Metrics & Grading
**Feeds into:** Metrics & Grading (scorecard), Tournament (promotes), Graveyard (kills), Experiment Tracking (logs every run)
**Tech:** VectorBT (open source initially, Pro if justified by specific bottleneck), NumPy/SciPy for Monte Carlo, custom orchestration for walk-forward and sensitivity sweeps
**Key risk:** Making it easy to fool yourself. The engine should default to conservative assumptions and make it hard to cherry-pick good results.

-----

### M5: Metrics & Grading System

**Tier:** 1 — Foundation
**What it does:** Standardized evaluation framework used at EVERY stage. Same rubric in backtest, tournament, paper, and live. No stage uses different criteria.

**Scoring dimensions:**

- Realized return (absolute and risk-adjusted)
- Realized drawdown (max, duration, frequency)
- Stability (consistency of monthly/quarterly returns, equity curve smoothness)
- Implementation shortfall (theoretical vs actual execution — relevant in paper and live)
- Correlation contribution (how much diversification does this add to the portfolio?)
- Behavior vs expectation (does actual performance match the backtest characterization?)
- Operational reliability (uptime, execution success rate — relevant in paper and live)
- Statistical confidence (are the results distinguishable from noise?)

**Depends on:** Receives data from Backtest, Tournament, Paper, Live
**Feeds into:** Every decision gate (promote, demote, kill, adjust, allocate)
**Tech:** Python, pyfolio/QuantStats for calculation primitives, custom scoring/comparison logic
**Key risk:** Vanity metrics. Optimize grading to surface failures and weaknesses, not to make strategies look good.

-----

### M6: Experiment Tracking & Reproducibility

**Tier:** 1 — Foundation
**What it does:** Records everything about every run so any result can be reproduced exactly and any comparison is apples-to-apples.

**Run Manifest — captured for every backtest, tournament session, and paper run:**

- Git commit hash (code version)
- Strategy version (name + version tag)
- Feature versions (all features used + their version tags)
- Parameter set (exact values used)
- Data snapshot identifier (what data state was used)
- Universe version (what instruments were included)
- Cost model version (commission schedule, slippage model)
- Random seeds (for any stochastic elements including Monte Carlo)
- Run timestamp
- Environment (Python version, package versions, OS)
- Run type (backtest, walk-forward, sensitivity sweep, Monte Carlo, tournament, paper)

**Depends on:** Git (code versioning), Data Layer (data snapshots), Strategy Factory (strategy versions)
**Feeds into:** All evaluation stages (ties results to exact conditions), Graveyard (kill records reference manifests)
**Tech:** Structured JSON or MySQL records, Git commit hashes, can start simple and formalize over time
**Key risk:** Not doing it. This is invisible until you need it, and then it’s too late. Build it in from the first real backtest run.

-----

### M7: Research Governance

**Tier:** 2 — Pipeline
**What it does:** Controls how ideas enter the system. Prevents the incubator from becoming a parameter casino.

**Idea Intake Template (filled out before any strategy reaches the Factory):**

- What anomaly/edge are we testing?
- Why should this edge exist? (economic rationale)
- Why should it persist? (why hasn’t it been arbed away?)
- Where might it fail? (known failure modes)
- What data does it require?
- What features does it need?
- What benchmark should it beat?
- What costs matter most?
- What would falsify it? (specific, testable)
- What similar strategies have we already tried? (check Graveyard)

**Depends on:** Graveyard (search before proposing), Feature Registry (what’s available)
**Feeds into:** Strategy Factory (accepted ideas become strategy definitions)
**Tech:** Markdown templates in repo. No infrastructure needed — this is discipline, not software.
**Key risk:** Skipping it when you’re excited about an idea. The template exists to slow you down just enough to think clearly.

-----

### M8: Tournament Arena

**Tier:** 2 — Pipeline
**What it does:** Runs multiple strategies head-to-head on live or near-live data. Comparative validation — not “is this good?” but “is this better than the alternatives?”

**Scoring (multi-dimensional, not just returns):**

- Realized return (risk-adjusted)
- Realized drawdown
- Stability / consistency
- Implementation shortfall (if applicable)
- Correlation contribution (to existing portfolio)
- Behavior vs backtest expectation
- Operational reliability

**Gate Criteria (Tournament → Paper):**

- Minimum tournament duration (calibrate with real data — likely 4-8 weeks minimum)
- Top performer in cohort across composite score (not just highest return)
- Metrics consistent with backtest characterization
- Low correlation with strategies already in paper/live
- No unexplained behavioral anomalies

**Depends on:** Data Layer (live/delayed feed), Strategy Factory, Metrics & Grading, Experiment Tracking
**Feeds into:** Paper Trading (promotes), Graveyard (demotes), Backtest (sends back for adjustment)
**Tech:** Custom orchestration, Alpaca paper trading API for execution simulation
**Key risk:** Not running long enough. Needs enough market conditions to be meaningful.

-----

### M9: Paper Trading Bridge

**Tier:** 2 — Pipeline
**What it does:** Final validation before real capital. Runs qualified strategies against live market conditions with simulated money.

**Gate Criteria (Paper → Live):**

- Minimum paper duration (calibrate — likely 4-8 weeks)
- Implementation shortfall within acceptable bounds
- No unexplained divergence from backtest/tournament characterization
- Circuit breaker levels defined and documented pre-deployment
- Capital allocation determined via Portfolio & Risk Engine
- Paper twin continues running alongside live for ongoing comparison

**Depends on:** Data Layer, Strategy Factory, Metrics & Grading, Broker API
**Feeds into:** Live Deployment (promotes), Tournament (demotes), Graveyard (kills)
**Tech:** IBKR paper trading via maintained API layer (ib_insync provisional — see dependency note), Alpaca as alternative

**DEPENDENCY NOTE — ib_insync:**
The ib_insync library was archived March 2024 (read-only, no new maintenance). It still functions but should be treated as provisional infrastructure, not permanent. The system should abstract broker interaction behind an internal interface so that swapping ib_insync for a maintained alternative (or direct IBKR TWS API) requires changing one module, not the entire system. Evaluate alternatives at build time — candidates include ib_async, nautilus_trader’s IBKR adapter, or direct TWS API wrapper.

-----

### M10: Graveyard & Archive

**Tier:** 2 — Pipeline
**What it does:** Records every strategy that was tested and failed, why it failed, and what we learned. Institutional memory. Over years, potentially more valuable than any single winning strategy.

**Kill Record contents:**

- Strategy ID and version
- Full scorecard at time of death
- Run manifest of the run that triggered the kill
- Kill reason (specific: “Sharpe collapsed in walk-forward” not “didn’t work”)
- Failure pattern tag (overfitting, regime-specific, data quality, execution gap, capacity, etc.)
- Strategy lineage (parent strategy if this was a modification)
- Lessons / notes (what did this teach us?)

**Depends on:** Receives killed strategies from all pipeline stages, references Experiment Tracking manifests
**Feeds into:** Research Governance (search before proposing new ideas), Strategy Factory (prevents redundant work), Failure Pattern Analytics (Tier 4)
**Tech:** MySQL or structured JSON, searchable by edge type, failure pattern, date range, strategy lineage
**Key risk:** Not using it. Check the graveyard before every new strategy proposal.

-----

### M11: Portfolio & Risk Engine

**Tier:** 3 — Operations
**What it does:** Converts individual strategy outputs into portfolio-level actions under capital, correlation, exposure, and risk constraints. A strategy can be individually fine and still be toxic in a portfolio — this module prevents that.

**Responsibilities:**

- Position sizing (per-strategy, per-trade, risk-normalized)
- Volatility targeting (normalize risk contribution so one strategy doesn’t dominate portfolio vol)
- Strategy allocation (weight by confidence level, risk-adjusted return, track record length)
- Exposure controls (caps by asset, sector, theme, strategy — prevents hidden concentration)
- Correlation-aware scaling (highly correlated strategies share one allocation bucket)
- Margin and cash constraints (available capital, reserve for new deployments, drawdown buffer)
- Rebalance logic (frequency, drift thresholds, triggers)
- Portfolio-level circuit breaker (total portfolio drawdown kill-switch — separate from per-strategy breakers)
- Strategy roster management (active, probation, benched, development, retired)

**Why this is its own module (not part of Live Deployment):**
Portfolio construction logic applies during backtesting (multi-strategy backtests), tournament (allocation simulation), paper (realistic sizing), and live. It’s cross-cutting. Burying it inside Live Deployment means you can’t test portfolio-level behavior until you’re already deploying capital.

**Depends on:** Metrics & Grading (strategy scorecards, correlation data), Strategy Factory (strategy metadata), Data Layer
**Feeds into:** Live Deployment (allocation instructions), Paper Trading (realistic sizing), Tournament (portfolio simulation)
**Tech:** Custom Python, potentially scipy for optimization
**Key risk:** Two “different” strategies that are really one bet wearing two hats. The correlation analysis must be honest.

-----

### M12: Live Deployment Manager

**Tier:** 3 — Operations
**What it does:** Executes strategies with real capital. Manages orders, positions, P&L, and circuit breakers.

**Depends on:** Portfolio & Risk Engine (allocation, sizing, risk limits), Strategy Factory, Data Layer, Broker API, Metrics & Grading
**Feeds into:** Metrics & Grading (live performance), Alert System (events), Experiment Tracking (live run records)
**Tech:** Python, IBKR API (abstracted behind internal interface — see M9 dependency note on ib_insync)
**Key risk:** Deploying before the pipeline above it is trustworthy. Emotional override of circuit breakers.

-----

### M13: Alert & Notification System

**Tier:** 3 — Operations
**What it does:** Keeps you informed across all pipeline stages without requiring constant dashboard monitoring.

**Alert categories:**

- Circuit breaker triggers (strategy-level or portfolio-level)
- Performance divergence (live vs paper/backtest mismatch)
- Data quality issues (gaps, stale feeds, provider outage)
- Tournament events (promotion, demotion, cohort results)
- Execution failures (order rejected, API error, connectivity)
- Regime change detected
- Experiment tracking anomalies (run failed to log properly)

**Depends on:** All modules (receives events from everywhere)
**Feeds into:** You (the human in the loop)
**Tech:** Python, Teams/Telegram — reuses MIC3 PM dispatch pattern
**Key risk:** Alert fatigue. Be selective. A noisy alert system gets ignored.

-----

### M14: Regime Monitor

**Tier:** 4 — Intelligence
**What it does:** Classifies market conditions. Provides context for evaluation, allocation, and strategy selection.

**Regime taxonomy (start simple, extend as needed):**

- Bull (sustained uptrend)
- Bear (sustained downtrend)
- Sideways (range-bound)
- Crisis (sharp drawdown, vol spike)
- High volatility (elevated but not crisis)
- Low volatility (compressed, calm)

**Depends on:** Data Layer
**Feeds into:** Backtest Engine (regime labels), Tournament (context), Live Deployment (allocation), Metrics & Grading (regime-tagged evaluation)
**Tech:** Can start as simple VIX thresholds + trend indicators. Gets more sophisticated over time.
**Key risk:** Overcomplicating it. A simple 4-6 regime model you can interpret beats a 20-regime model you can’t.

-----

### M15: Adaptive Allocation

**Tier:** 4 — Intelligence
**What it does:** Uses regime information and rolling performance to dynamically adjust strategy weights and roster composition.

**Relationship to M11 (Portfolio & Risk Engine):** M11 is always-on portfolio construction and risk control — it enforces sizing, exposure caps, correlation limits, and circuit breakers regardless of market conditions. M15 is an optional intelligence layer that modifies M11’s inputs (target weights, roster recommendations) based on regime context and rolling performance. M11 defines the rules of the game. M15 suggests which players to put on the field. M11 always has final authority — M15 cannot override M11’s risk constraints.

**Depends on:** Regime Monitor, Portfolio & Risk Engine, Metrics & Grading, Tournament (bench candidates)
**Feeds into:** Portfolio & Risk Engine (suggested weight adjustments, roster recommendations — M11 decides whether to accept)
**Tech:** Custom Python, rules-based initially (not ML)
**Key risk:** Over-rotating. Regime detection has lag. Adaptive allocation should be a gentle tilt, not aggressive regime-timing.

-----

## Cross-Cutting Contracts (Shared Interfaces)

These are NOT modules — they are shared specifications that multiple modules depend on. They need to be defined before or alongside the modules that use them.

### Strategy Contract

**Used by:** M2, M4, M5, M8, M9, M11, M12
**Defines:** The interface every strategy must implement. Inputs, outputs, parameters, metadata.

### Scorecard Format

**Used by:** M5, M8, M9, M10, M11, M12
**Defines:** Standardized evaluation output. Same structure everywhere so strategies can be compared across stages.

### Run Manifest Format

**Used by:** M6, M4, M8, M9, M12
**Defines:** What every run records. Enables reproducibility and apples-to-apples comparison.

### Kill Record Format

**Used by:** M10, M5, M6
**Defines:** What gets recorded when a strategy dies. Enables graveyard search and failure analysis.

### Promotion/Demotion Rules

**Used by:** M8, M9, M11, M12
**Defines:** Formal gate criteria at each transition. Actual rule tables, not vague prose.
**Ownership model:** This contract is the single source of truth for all gate logic. M5 (Metrics) calculates scores and evaluates evidence. This contract defines the canonical rule tables (thresholds, durations, conditions). M8/M9/M11/M12 apply the stage-specific rules defined here — they do not invent their own. If a gate criterion needs to change, it changes here first, then propagates. This prevents promotion/demotion logic from drifting across modules over time.

### Alert Event Schema

**Used by:** M13, all modules that emit events
**Defines:** Standardized event format so any module can emit alerts without coupling to the notification system.

### Broker Abstraction Interface

**Used by:** M9, M12
**Defines:** Internal interface for broker interaction. Decouples system from specific broker API/library (insulates from ib_insync archival risk).

### Architecture Decision Records (ADRs)

**Used by:** All modules, all future development sessions
**Defines:** A lightweight log of major design decisions, what was decided, why, what alternatives were considered, and what would cause us to revisit. Stored as numbered markdown files in the repo (e.g., `ADR-001-vectorbt-as-backtest-core.md`). Purpose: prevent re-litigating settled architecture in future sessions. When a decision is made — technology choice, module boundary, contract design, build-vs-buy — it gets an ADR. Any future session that touches that area reads the ADR first instead of re-deriving the reasoning. This is especially critical for long-horizon AI-assisted development where context doesn’t persist between sessions.

-----

## Strategy Lifecycle — Complete Pipeline

```
                    ┌─────────────┐
                    │  IDEA INTAKE │ (M7 — Research Governance)
                    │  template    │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
           ┌───────│   GRAVEYARD  │ check for prior similar failures
           │       │   SEARCH     │
           │       └──────┬──────┘
           │              │ (no match found — proceed)
           │       ┌──────▼──────┐
           │       │   STRATEGY   │ (M2 — define contract + metadata)
           │       │   DEFINE     │
           │       └──────┬──────┘
           │              │
           │       ┌──────▼──────┐
           │       │  BACKTEST    │ (M4 — characterize, don't just pass/fail)
           │       │  & PROFILE   │
           │       └──────┬──────┘
           │              │
           │         FAIL │ PASS ──────────────────────┐
           │              │                            │
           │       ┌──────▼──────┐              ┌──────▼──────┐
           │       │  GRAVEYARD   │              │  TOURNAMENT  │ (M8)
           │       │  + KILL LOG  │              │  ARENA       │
           │       └─────────────┘              └──────┬──────┘
           │                                          │
           │                                    FAIL  │  PASS
           │                                     │    │
           │                              ┌──────▼────▼──────┐
           │                              │                   │
           │                       ┌──────▼──────┐    ┌──────▼──────┐
           │                       │   ADJUST &   │    │   PAPER     │ (M9)
           │                       │   RE-ENTER   │    │   TRADING   │
           │                       └──────┬──────┘    └──────┬──────┘
           │                              │                  │
           │                              │            FAIL  │  PASS
           │                              │             │    │
           │                              ◀─────────────┘    │
           │                                          ┌──────▼──────┐
           │                                          │    LIVE      │ (M12)
           │                                          │  DEPLOYMENT  │
           │                                          └──────┬──────┘
           │                                                 │
           │                                          [CIRCUIT BREAK]
           │                                                 │
           │                                          ┌──────▼──────┐
           │                                          │  DEMOTE TO   │
           │                                          │  PAPER/TOURN │
           │                                          └──────┬──────┘
           │                                                 │
           │                                          (re-evaluate)
           │                                                 │
           └─────────────────────────────────────────────────┘
                                                    (or kill → graveyard)
```

-----

## Technology Stack

|Component              |Technology                |Status        |Notes                                          |
|-----------------------|--------------------------|--------------|-----------------------------------------------|
|Language               |Python 3.x                |Confirmed     |Primary for everything                         |
|Backtest Core          |VectorBT open source      |Start here    |Upgrade to Pro ($500 lifetime) if justified    |
|Data Storage           |MySQL                     |Existing      |Running on Honey Duo workstation               |
|Broker — Live          |IBKR TWS API              |Confirmed     |Abstract behind internal interface             |
|Broker Lib             |ib_insync                 |PROVISIONAL   |Archived March 2024 — plan for replacement     |
|Broker — Paper Alt     |Alpaca API                |Free tier     |Good for tournament, IEX data limitation noted |
|Performance Metrics    |pyfolio / QuantStats      |Helper only   |Use for calculations, keep scoring logic custom|
|Monte Carlo            |Custom (NumPy/SciPy)      |Build         |Drawdown distribution simulation               |
|Visualization          |Plotly / VectorBT built-in|Use           |Interactive charts, dashboards                 |
|Notifications          |Python (Teams/Telegram)   |Pattern exists|Reuse MIC3 PM dispatch pattern                 |
|Version Control        |Git / GitHub              |Existing      |Strategy + feature + code versioning           |
|Scheduling             |cron / systemd            |Existing      |Already used on Honey Duo                      |
|Heavy Compute          |RTX 3090 workstation      |Existing      |Parameter sweeps, Monte Carlo                  |
|Light Compute / Monitor|Raspberry Pi 5            |Existing      |Monitoring, alerts, lightweight tasks          |

-----

## Open Questions

1. **Data provider selection and budget** — Yahoo Finance (free, daily EOD), Alpaca (free, minute bars), or paid (Polygon ~$30/mo, Tiingo)? What resolution do we actually need for v1 strategies?
1. **ib_insync replacement path** — evaluate ib_async, nautilus_trader IBKR adapter, or direct TWS API wrapper at build time. Define broker abstraction interface early so this swap is painless.
1. **Tournament duration thresholds** — needs real data to calibrate. Start with 4-8 week minimum, adjust based on observed strategy cycle times.
1. **Circuit breaker multipliers** — 1.5x or 2x backtest P95 drawdown? Start conservative (1.5x), loosen if it causes too many false triggers.
1. **Asset class scope for v1** — US equities and ETFs only? Or include options/futures from the start? Recommend constraining to equities/ETFs initially.
1. **Compute profiling** — will RTX 3090 handle full universe parameter sweeps? Profile early.
1. **Alpaca IEX data limitation** — paper tournament uses IEX feed, backtests may use broader data. Account for this discrepancy in tournament evaluation.
1. **VectorBT open source vs Pro** — start open source. Evaluate Pro when specific bottleneck appears. $500 lifetime is low risk if justified.

-----

## Dependency Summary

```
CRITICAL PATH (must exist in order):

  Data Layer (M1)
       │
       ├── Feature Registry (M3) ── can develop alongside M1
       │
       ├── Strategy Factory (M2) ── needs M1 schemas + M3 features
       │
       ├── Experiment Tracking (M6) ── needs to exist before first real run
       │
       └── Backtest Engine (M4) ── needs M1 + M2 + M3
                │
                └── Metrics & Grading (M5) ── needs M4 output to design against
                         │
                         └── everything else builds on top of this foundation

CROSS-CUTTING (define alongside, not after):

  Strategy Contract ── before M2 is built
  Scorecard Format ── before M5 is built
  Run Manifest Format ── before M6 is built
  Broker Abstraction ── before M9 is built
```

-----

*Document version: 0.3*
*Created: April 2026*
*Status: End-state system definition — architecturally complete, field-validated, implementation phased*
*Changelog v0.2: Added Portfolio & Risk Engine (M11), Feature Registry (M3), Experiment Tracking (M6), Research Governance (M7), Adaptive Allocation (M15). Restructured Data Layer into logical tiers. Added structured strategy metadata. Added cross-cutting contracts. Flagged ib_insync as provisional. Revised backtest gate criteria to use evidence thresholds instead of fixed trade count. Added architectural tier classifications.*
*Changelog v0.2.1: Clarified Promotion/Demotion Rules ownership model (M5 calculates, contract defines rules, stage modules apply). Tightened M11/M15 boundary (M11 = always-on risk control, M15 = optional intelligence that suggests to M11, M11 has final authority). Added Architecture Decision Records (ADRs) as cross-cutting contract for preserving design rationale across sessions.*
*Changelog v0.3: Added Architectural Principles section — eight non-negotiable design constraints validated by field research across LEAN, NautilusTrader, QSTrader, pysystemtrade, and practitioner accounts. Key additions: backtest-to-live code parity as mandatory constraint, modular monolith over microservices, data quality validation as first-class concern, conservative cost modeling defaults, system health monitoring scope expansion, regime simplicity principle, core loop before intelligence layer, portfolio simplicity principle.*I