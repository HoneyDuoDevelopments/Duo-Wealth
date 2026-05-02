# Research Topic: Phase 1 Build Plan

## Question

How does Phase 1 (the data foundation build) execute concretely, given the architecture locked in ADR-003 and the April 2026 architectural audit's Findings 4, 5, 6, and 14?

## Why It Matters

Phase 1 is the load-bearing foundation. Sequencing errors propagate into every downstream phase — three-warehouse validation, Phase C, and the DataDuo launch all depend on Phase 1 producing a trustworthy, reconcilable dataset. Documenting the locked plan in the repo prevents drift across future sessions and gives any executor of Phase 1A-A1 a single canonical reference for sequencing, scope, and exit criteria.

## Sources Reviewed

- `adrs/ADR-003-independent-public-domain-pipeline-architecture.md` — the architectural stance this plan operationalizes
- `audits/System_Audit_And_Documentation_Update_Plan_April_2026.md` — Findings 4 (lifecycle), 5 (multi-source adapter), 6 (reconciliation), 14 (universe-and-lifecycle-first sequencing)
- `audits/Phase 1 Build Plan — Documentation Update Plan.md` — the scoping document that produced this plan
- `contracts/` — `validation-protocol.md` (three-warehouse methodology this plan enables), `price-source-adapter.md` (Stage 6 adapter interface), `data-provenance-schema.md` (Stages 6–9 provenance), `reconciliation-report-schema.md` (Stage 8 discrepancy records)
- `roadmap.md` v1.1 — Phase 1A-A1 / A2 / A3 sequencing this plan refines
- Cross-session deliberation, April 24–25, 2026, including external skeptical review (GPT, Gemini)
- Empirical web search confirming Stooq's adjustment-state behavior (no separate raw series exposed) — drove the reverse-adjustment-engine-before-price-ingestion sequencing

## Locked Plan

The following six sections (1.1 through 1.6) are reproduced verbatim from Part 1 of `audits/Phase 1 Build Plan — Documentation Update Plan.md` as the canonical Phase 1 build plan. They are not for re-examination during execution.

### 1.1 Scope

**Phase 1 build scope:** S&P 500 universe, 2005-01-01 through present.

**Phase 1 architectural scope (does not exit until both are done):** S&P 500 + S&P 400 (MDY proxy) + S&P 600 (IJR proxy). Built sequentially — S&P 500 first, MDY/IJR follow-on within the same phase.

**Coverage period rationale:** 2005 is where every source we depend on has reliable coverage simultaneously — fja05680 stable, SEC Form 25 delistings observable, EDGAR XBRL fundamentals available, corporate actions via 8-K fully available. Going earlier (1996 via fja05680, with quality caveats pre-2001) is rejected because market structure has changed materially since 2005 and regime coverage from a fundamentally different market is worth less than tighter, more relevant coverage.

**Out of scope for Phase 1 entirely:**

- FRD validation (post-Phase-1)
- Strategy backtests across the three warehouses (Phase B)
- Fundamentals, macro data, earnings calendar (Phase C enrichment)
- Forward-feed IBKR ingestion as a Phase 1 deliverable (it's used in Warehouse B forward maintenance, but Phase 1 is historical bootstrap)
- DataDuo deployment concerns (parallel track, post-Phase-B)
- Universe expansion beyond S&P 500 + S&P 400 + S&P 600 (Russell etc. is v2)

### 1.2 Core Thesis

This phase builds a self-correcting data system, not a static dataset. Accuracy improves through reconciliation across independent sources. The system is designed to detect and correct its own errors, not to be perfect on first pass.

### 1.3 The 11-Stage Sequence

Stages are ordered by dependency, not by calendar. No durations are specified.

**Stage 0 — Scaffold the work area.** Create module spec skeletons, contract skeletons (already done in the April 19 audit), research topic files, dedicated PostgreSQL test schema. Exit: skeletons committed.

**Stage 1 — Identity spine for S&P 500 universe.** Ingest SEC `company_tickers.json`, SEC submissions data for entity continuity, integrate OpenFIGI for FIGI assignment. Build `instrument_master` and `instrument_identifier_history` tables with `(ticker + date_range)` as composite key — ticker lookups without a date must error, warn, or return all historical mappings, never silently pick one. Separate `issuer_id`, `instrument_id`, `share_class_id` explicitly; CIK alone is never security identity. Validate against deliberate hard cases (Google → Alphabet, GOOG/GOOGL, BRK.A/BRK.B, name change without ticker change, ticker reuse if findable in 2005+). Exit: any historical S&P 500 ticker resolves to durable instrument_id with full identifier history.

**Stage 2 — S&P 500 membership from bulk source.** Ingest fja05680/sp500 for 2005+ (full 1996+ data preserved in raw store). Normalize into `universe_membership_event` records with `effective_date`, `effective_date_confidence`, `observed_date`, `source_observed_date`. Build `universe_snapshot` derivation logic. Exit: derivable S&P 500 membership at any date since 2005 with confidence metadata.

**Stage 3 — Press release validation overlay.** Collect S&P Global press releases for 2005+. Parse into `universe_membership_event` records with higher source_confidence than fja05680. Reconcile: agreement upgrades confidence, disagreement creates `reconciliation_case` records. Press release wins where both present. Exit: validated membership with reconciliation cases documented.

**Stage 4 — Corporate action events.** Parse EDGAR 8-K filings: Item 5.03 (splits), Items 1.01/2.01 (mergers), Item 3.01 (delistings), Item 8.01 (dividends). Build `corporate_action_event` records with multiple date fields (`announcement_date`, `ex_date`, `record_date`, `payable_date`, `effective_date`, `source_observed_date`) — `ex_date` for price math, `effective_date` for identity continuity. Handle spinoffs explicitly with parent-child linkage. Document reverse-merger handling as known v1 limitation. Exit: events captured to the extent observable from EDGAR; completeness is validated and improved through downstream reconciliation in Stage 8.

**Stage 5 — Reverse-adjustment engine.** Build cumulative split factor computation, cumulative dividend adjustment factor, the reverse-adjustment function (adjusted series + event log → unadjusted series). Spot-check reversed prices against any known raw-price reference points before trusting at scale. Exit: engine works deterministically on test cases. The same engine, run forward, becomes Stage 9. Why this comes before price ingestion: Stooq delivers fully adjusted with no separate raw series — empirically confirmed via web search during deliberation. We cannot store Stooq data as raw without reverse-adjusting at ingestion. The engine has to exist first.

**Stage 6 — Stooq adapter and ingestion.** Build the price source adapter contract implementation. Implement Stooq adapter. Ingest Stooq prices for the S&P 500 universe across 2005+. Apply reverse-adjustment at ingestion using Stage 5 engine. Store with full provenance per `contracts/data-provenance-schema.md`. Use structured `adjustment_state_received` taxonomy: `split_adjusted`, `dividend_adjusted`, `total_return_adjusted`, `split_and_dividend_adjusted`, `unknown_adjusted` — actual value confirmed empirically before locking. Stooq-derived unadjusted is treated as one input to reconciliation, not as ground truth.

**Stage 7 — yfinance adapter and parallel ingestion.** Implement yfinance adapter behind the same contract. yfinance typically delivers adjusted close and raw close together — store both with explicit provenance distinguishing them. No reverse-adjustment needed for yfinance unadjusted; it's delivered native. Known limitation: yfinance coverage of historical delisted tickers is weaker than Stooq. yfinance primarily serves as independent cross-validation for active tickers and a disagreement detector — not a comprehensive source for the full historical universe.

**Stage 8 — Cross-source reconciliation.** Compare Stooq-derived unadjusted (post-reverse-adjustment) against yfinance native unadjusted for every instrument-day where both have coverage. Generate `reconciliation_case` records per `contracts/reconciliation-report-schema.md`. Categorize disagreements with predefined categories: `adjustment_factor_mismatch`, `adjustment_methodology_mismatch`, `localized_discontinuity_around_event_date`, `data_quality_issue_single_source`, `edge_case_in_reverse_adjustment_logic`, `unresolved_unknown`. Resolution rules per category; ad hoc decisions not permitted. When disagreement reveals a missing corporate action event, update Stage 4 event log and re-run Stage 5 reverse-adjustment for affected instruments. `known_unresolved_discrepancy` is a valid end state.

**Stage 9 — Forward-adjustment engine and adjusted series.** Apply the Stage 5 engine forward (raw + events → adjusted). Produce both split-adjusted and total-return-adjusted series. Store as derived views over raw + corporate actions; may be materialized for performance but remain logically dependent on raw + event log. Three-way validation: pipeline-adjusted vs Stooq native adjusted vs yfinance native adjusted.

**Stage 10 — Gap fill from remaining sources.** Categorize remaining gaps. Evaluate additional free sources for each gap category. Implement additional adapters where worth the effort. Document gaps that remain unobtainable as explicit known limitations.

**Stage 11 — Phase 1 confidence review and exit.** Multi-dimensional confidence report: `identity_confidence`, `identifier_confidence`, `membership_confidence`, `corporate_action_confidence`, `split_adjustment_confidence`, `dividend_adjustment_confidence`, `price_raw_confidence`, `price_adjusted_confidence`, `coverage_confidence`. Distribution across the universe per dimension; tiers emerge from measurement, not pre-specified. Phase 1 exit does not require perfect data — it requires transparent, measured data quality.

### 1.4 Sequencing Logic

- Identity before membership (can't tag membership without knowing who's who)
- Membership before validation (need something to validate against)
- Membership before corporate actions (only act on instruments in scope)
- **Corporate actions before any prices** (every adjustment depends on the event log)
- **Reverse-adjustment engine before any price ingestion** (Stooq delivers adjusted-only; cannot store as raw without reversing)
- Stooq before yfinance (Stooq more comprehensive for delisted; yfinance is cross-validator for active)
- Reconciliation before forward-adjustment (cross-source disagreements may reveal missing events that affect adjustment math)
- Forward-adjustment derives from validated raw + validated events, not from any single source's adjusted data
- Gap fill comes after we know what's actually missing, not before
- Convergence loop, not linear import: Stage 8 feeds back to Stages 4, 5, and 6 until discrepancies stop surfacing or are explicitly deferred

### 1.5 Empirical Source Verification Gate

Before Stage 1 implementation begins, the following must be empirically verified:

1. What Stooq actually delivers for known test cases — confirm `adjustment_state_received` classification and whether documentation matches real data
2. What yfinance actually delivers for the same test cases — confirm adjusted and unadjusted both exposed as expected, measure coverage for delisted tickers in our 2005+ universe
3. What SEC and OpenFIGI APIs return for our identity-resolution hard cases — confirm coverage and rate limits are workable at universe scale

Results documented in `research/topics/source-empirical-verification-stooq-yfinance.md` (new file, structure per `research/research-method.md` template; created during the empirical test, not by this Claude Code session).

### 1.6 MDY/IJR Sequencing Within Phase 1

Phase 1A-A1 architectural scope covers S&P 500 + S&P 400 (MDY N-PORT) + S&P 600 (IJR N-PORT). Build sequence within A1 is sequential, not parallel:

1. S&P 500 first via fja05680 + press releases + datasets/s-and-p-500-companies — proves the architecture (identity spine, lifecycle registry, corporate action event log, reverse-adjustment engine, multi-source adapter, reconciliation engine)
2. MDY/IJR after S&P 500 work proves the architecture — extends universe coverage via N-PORT parsing, but reuses the already-built event log and adjustment engines

Splits and dividends are properties of instruments, not indices. The corporate action event log built during S&P 500 work serves MDY/IJR with no rework — only extension as additional instruments enter scope. The reverse-adjustment and forward-adjustment engines are also instrument-keyed and apply universally. Only membership reconstruction logic is genuinely index-specific (fja05680/press release vs N-PORT), which is why doing them sequentially teaches us something useful.

Phase 1A-A1 does not exit until S&P 500 and MDY/IJR coverage are both in place.

## Rationale

Each substantive call captured below is a decision the cross-session deliberation made deliberately, with the alternative considered and rejected.

- **Priceless universe before prices.** Universe is the harder problem — identity continuity across renames, delistings, ticker reuse, corporate actions, dual-class structure. Validating the universe before attaching prices means gaps become explicit (no instrument_id resolution) rather than silent (a price series attributed to the wrong entity).

- **Multi-source from the start (not single-ticker validation).** The April 19 audit's Phase 1A-A2 specified single-ticker (AAPL) end-to-end through a single adapter. The architecture's purpose is multi-source reconciliation; validating a single source on a single ticker proves only the plumbing. Stages 6–7 introduce Stooq and yfinance in parallel; Stage 8 reconciliation exercises what the architecture exists to do. Substantive deviation from the April 19 audit, made because the audit's A2 under-tested the load-bearing component.

- **2005 start date.** Every source has reliable coverage from 2005. Going earlier (fja05680 reaches back to 1996) pulls in market-structure regimes (decimalization mid-2001, post-Reg-NMS pre-2007) materially different from current market structure. Regime coverage from a different market is worth less than tighter, more relevant coverage.

- **MDY/IJR sequenced after S&P 500.** fja05680 + press releases is a different reconstruction problem from N-PORT parsing. Doing one well first teaches the patterns before tackling the second. Instrument-keyed infrastructure (event log, adjustment engines) carries forward without rework; only membership reconstruction is index-specific.

- **Reverse-adjustment engine before any price ingestion.** Stooq delivers fully adjusted prices with no separate raw series — empirically confirmed during the April 25 deliberation. Without the engine, ingestion would write source-adjusted prices into the canonical store, violating the unadjust-then-re-adjust principle (ADR-003). Stage 5 must exist before Stage 6 runs.

- **Confidence is multi-dimensional, not a single score.** Stage 11 reports nine dimensions (identity, identifier, membership, corporate action, split adjustment, dividend adjustment, price raw, price adjusted, coverage). Collapsing into a single score hides information downstream consumers (strategy authors, validation-protocol auditors, Comparative Truth Engine) need to decide which domains to trust at what fidelity.

- **Thresholds measured, not pre-specified.** No tier boundaries on the confidence dimensions are defined in advance. Pre-specifying either trivially passes or impossibly fails for reasons not yet understood. Phase 1 measures distributions; tiers emerge from measurement. Same empirical-tolerance pattern as Phase B thresholds in `contracts/validation-protocol.md`.

## Implications

- **Operationalizes ADR-003.** ADR-003 locks the pipeline-is-the-system, source-agnostic, FRD-as-validator, lifecycle-first architectural stance. This plan operationalizes that stance into 11 ordered, dependency-driven stages.

- **Implements audit Findings 4, 5, 6, 14.** Finding 4 (lifecycle registry) lands in Stages 1–4. Finding 5 (multi-source adapter) lands in Stages 6–7 against `contracts/price-source-adapter.md`. Finding 6 (reconciliation engine) lands in Stage 8 against `contracts/reconciliation-report-schema.md`. Finding 14 (universe-and-lifecycle-first sequencing) is the structural foundation.

- **Refines audit Finding 14's A1/A2/A3 split.** Audit A1 (Universe and Lifecycle Foundation) → Stages 0–4. Audit A2 (Single-Ticker Price Pipeline) → Stages 5–6 at universe scale, not single-ticker. Audit A3 (Scale and Multi-Source) → Stages 7–10. Stage 11 is the Phase 1 exit gate.

- **Enables three-warehouse validation downstream.** Phase 1 produces Warehouse A's public-domain ingestion path per `contracts/validation-protocol.md`. FRD ingestion for Warehouses B and C is a Phase B deliverable using the same adapter contract; Phase 1's contract enforces deployment eligibility (DataDuo refuses `frd` and `ibkr` adapters at registration).

- **Convergence loop interaction with Stage 4.** Stage 8 reconciliation may reveal missing corporate action events. The plan directs feedback into Stage 4 (event log) and Stage 5 (re-run reverse-adjustment) until discrepancies stop surfacing or are explicitly deferred as `known_unresolved_discrepancy`. This operationalizes the self-correcting property of the Core Thesis (Section 1.2).

- **Phase C and DataDuo unaffected by Phase 1 internals.** Phase C capability domain expansion and the DataDuo three-part product launch are downstream of Phase 1 exit. They consume Phase 1's universe and price output but do not influence its sequencing.

## Recommended Decision

Adopt this 11-stage sequence as the canonical Phase 1 build plan. No separate ADR is required: ADR-003 covers the architectural stance; this document operationalizes it. The roadmap's Phase 1A-A1 work-items section gets two surgical clarifications (sequential S&P 500 → MDY/IJR build order, and the empirical source verification gate) referencing this document for the full plan. Module specs for M1f (Lifecycle Registry), M1g (Price Source Adapter Layer), and M1h (Reconciliation Engine) reference the relevant stages in this plan when those specs are written during Phase 1A-A1 execution.

## Unresolved Questions

- **Empirical source verification gate (Section 1.5).** Three empirical questions must be answered before Stage 1 implementation begins. Documented in `docs/research/open-questions.md` as questions 4, 5, and 6 (added 2026-04-25). The empirical test produces `research/topics/source-empirical-verification-stooq-yfinance.md` — that file is created during the test itself, not by this documentation session.

- **Three-warehouse tolerance thresholds.** Recorded in `docs/research/open-questions.md` (question 2). Resolution is a Phase B deliverable; Phase 1 produces the public-domain ingestion that Warehouse A depends on but does not measure tolerances itself.

- **Reference strategy suite composition.** `contracts/validation-protocol.md` flags this as a Phase 1B deliverable. Phase 1 does not block on it.

- **Reverse-merger handling.** Stage 4 documents reverse-mergers as a known v1 limitation. Resolution path is unspecified; the limitation is accepted for v1 and surfaced explicitly in Stage 11's confidence report rather than hidden.

---

## Sequencing Note — 2026-05-01

The fja05680 universe loader (canonical Stage 2 in this build plan) was implemented before the SEC identity spine (canonical Stage 1). This is a deviation from the stage ordering specified above and is documented here for the record.

**Why this is defensible.** The schema in `db/migrations/001_identity_spine.up.sql` was designed with `instrument_master.issuer_id` nullable specifically so an instrument can exist with ticker evidence alone before CIK/issuer is resolved. Loading fja05680 first creates 1,246 provisional instruments with `issuer_id = NULL`, exactly the pattern the schema anticipated. Stage 1 work fills in those nulls without needing to recreate or modify any Stage 2 records.

**Why the build plan body is not being rewritten.** The build plan's Stage 1 → Stage 2 ordering remains the right ordering for *future* identity-spine builds (e.g., MDY/IJR universe expansion). The deviation taken for the S&P 500 build is a one-time pragmatic choice driven by fja05680 being a clean local CSV vs. SEC's API surface, and it does not change the dependency graph for downstream stages.

**Lock-in for Stage 1.** Stage 1 is not considered complete until both of the following are true:

1. Active issuer bridge: every active fja05680 instrument (`death_date IS NULL`) has its `issuer_id` populated from SEC `company_tickers.json`, and a corresponding `issuer_master` row exists with `primary_cik` and `legal_name` set.
2. Delisted issuer resolution: every delisted fja05680 instrument (`death_date IS NOT NULL`) has had a CIK lookup attempted via `data.sec.gov/submissions/CIK{10-digit}.json` keyed off the ticker history, and either:
   - has `issuer_id` populated to a resolved `issuer_master` row, OR
   - has an explicit `identifier_resolution_audit` row recording the unresolved status with reason

No Stage 3 (press release validation) or later work begins until both conditions hold.

**OpenFIGI integration timing.** OpenFIGI FIGI assignment happens within Stage 1 after issuer resolution, populating `figi_identifier_history` for every instrument where a compositeFIGI can be obtained. Active instruments will resolve cleanly; some delisted instruments (LEH, BSC) will not — those get explicit `figi_identifier_history` audit rows or are left out, with the rationale logged in `identifier_resolution_audit`.
