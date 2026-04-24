# HoneyDuo Wealth / DataDuo — Formal System Audit & Documentation Update Plan

**Date:** April 19, 2026
**Status:** Pre-build audit complete — awaiting documentation execution
**Trigger:** Cross-session review (Gemini) surfaced potential delisting/survivorship gap. Subsequent deep discussion revealed the gap was symptomatic of larger architectural drift accumulated across recent sessions.
**Purpose:** Comprehensive audit of all project documentation against the locked architectural vision, with explicit change instructions for next session to execute.

---

## Part 1 — The Locked Architectural Vision (Authoritative)

Before any audit findings, this document states the architecture explicitly so there is zero ambiguity going forward. Every finding in Part 2 is measured against this.

### 1.1 The System

**The system is a single independent data ingestion and enrichment pipeline.**

- Built from fully redistributable public-domain sources
- Produces a complete research/backtesting warehouse covering everything except prices
- Source-agnostic for prices — can ingest from any provider (free or paid) and apply identical enrichment
- Validated against FRD as a benchmark, **not dependent on FRD**
- The pipeline is the product; data sources are inputs; FRD is a validator

### 1.2 The Two Deployments

**One codebase. Two deployments. Different data serving scopes.**

**Duo Wealth (local deployment):**
- Runs the full pipeline
- Supplements with FRD (historical backfill, personal license) and IBKR (forward feed, personal license)
- FRD serves as validation teacher and audit benchmark
- Purpose: personal trading research and execution

**DataDuo (cloud VPS deployment):**
- Runs the same pipeline codebase
- Ingests only from redistributable public-domain sources
- Serves enrichment outputs only — never prices
- Purpose: public product serving the pipeline's non-price output

### 1.3 The Three-Part DataDuo Product

DataDuo is not just an enrichment API. It is three deliverables:

1. **Enrichment API** — serves universe membership history, corporate actions, fundamentals, short interest, holdings, insider data, calendar, macro, lifecycle registry
2. **"Build Your Own Warehouse" methodology** — documentation/guide teaching retail users how to construct a backtest-ready warehouse from free price sources enriched by DataDuo outputs
3. **Comparative Truth Engine** — ongoing published comparison showing how close a free-data-plus-DataDuo-enrichment system performs against an FRD-assisted system on reference strategies. The honest accuracy delta is the trust anchor.

### 1.4 The Three-Warehouse Validation Protocol

The pipeline is validated by triangulating three independently-sourced warehouses:

**Warehouse A — DataDuo Warehouse**
- Prices: free sources (Stooq primary, yfinance/others for gap-fill)
- Enrichment: pipeline output
- Forward maintenance: IBKR daily feed enriched by pipeline
- **Tests the claim:** "The pipeline produces trustworthy output from public-domain sources."

**Warehouse B — Duo Wealth Warehouse**
- Prices: FRD historical backfill + IBKR forward feed
- Enrichment: pipeline output
- **Tests the claim:** "The pipeline works correctly when given premium price data."

**Warehouse C — Test Warehouse**
- Prices: FRD
- Enrichment: pipeline output applied to FRD-sourced data
- Forward maintenance: FRD's one-month free update window
- **Tests the claim:** "Our pipeline logic matches FRD's native output when given the same underlying data."

Validation sequence:
1. Backtest identical test strategies across all three warehouses
2. Compare scorecards — Sharpe, CAGR, max DD, trade counts should align within measured tolerance
3. Strategies that pass across all three promote to paper trading from each warehouse
4. Paper trading results compared against backtest characterization for each warehouse
5. Only strategies that behave consistently across all three environments earn the right to go live

**What this protocol proves:** three independent claims simultaneously — pipeline logic is sound (C vs FRD native), public-domain sources are sufficient (A vs B), strategies are robust (survive data source variation).

### 1.5 The Universe-and-Lifecycle-First Build Principle

**The universe registry and lifecycle tracking are built before any prices.**

Knowing *what* existed and *when* is the foundation everything else depends on. Prices without universe membership produce guessing backtests. Universe membership without prices produces a skeleton that any price source can hang from.

Phase 1 build order:
1. Define universe coverage scope (S&P 500, S&P 400, ETFs)
2. Build lifecycle registry from public-domain sources (SEC Form 25, 8-K Item 3.01, OpenFIGI, EDGAR CIK history)
3. Build index membership history from public-domain sources (MDY/IJR N-PORT, fja05680, datasets/s-and-p-500-companies)
4. Cross-reconcile — produce the authoritative "here's every ticker that existed between 2005 and present, here's when it listed/delisted, here's what index it was in, here's when it changed"
5. Only then begin price ingestion

### 1.6 The Unadjust-Then-Re-adjust Principle

**The pipeline applies its own corporate action logic to every price source — uniformly.**

No source is trusted for adjustments. For every price source (Stooq, yfinance, IBKR, FRD, any future source):
1. Ingest whatever adjustment state the source provides
2. Reverse-engineer back to unadjusted raw using source-specific reversal logic
3. Store raw in canonical layer with data provenance metadata (source, original state, reversal applied)
4. Apply the pipeline's own adjustment factors (derived from EDGAR 8-K Item 5.03 parsing) to produce research-tier adjusted prices

This is what makes the pipeline source-agnostic and what makes the three-warehouse validation meaningful — each warehouse's prices are normalized through identical logic.

### 1.7 "Bootstrap Once, Maintain Forever"

**This is the unifying architectural principle, not a feature of one subsystem.**

Because every public-domain source the pipeline depends on keeps publishing on its own schedule indefinitely, the forward maintenance cost approaches zero after the historical bootstrap is complete. The pipeline is perpetual motion after initial validation. This applies to the entire pipeline, not just universe reconstruction.

---

## Part 2 — Audit Findings

Each finding identifies: (a) where the drift exists in current documentation, (b) what's wrong about it, (c) the corrected framing, (d) specific change instructions.

### CRITICAL DRIFT — Must Fix Before Build

---

#### Finding 1: DataDuo framed as downstream consumer rather than parallel deployment

**Where the drift exists:**
- Session wrap-up document (Landscape Review v1.1), Part 4 "Verdict on the S&P 400/600 gap"
- Session wrap-up document Part 5 "Updated DataDuo Feature Group Count"
- Handoff document Section "Decisions Locked This Session" items 3 and 4
- Both documents repeatedly use language like "DataDuo gets" and "DataDuo serves" as if DataDuo is a downstream surface consuming pipeline outputs

**What's wrong:**
Under the locked vision, DataDuo is a parallel deployment of the same pipeline codebase, not a downstream product. The pipeline ingests from public-domain sources; DataDuo is the deployment that serves those outputs. Framing DataDuo as a downstream consumer subtly displaces the pipeline from its central architectural position.

**Corrected framing:**
The pipeline is the system. Duo Wealth is one deployment of that pipeline (with FRD+IBKR supplementation). DataDuo is another deployment of that pipeline (public-domain only). Both deployments ingest, enrich, and produce output through the same codebase. What differs is the data sources each deployment has access to and what each deployment serves to users.

**Change instructions:**
1. **Blueprint M1 section (lines 181-205):** Prepend a new paragraph before "Internal structure" establishing the two-deployment architecture explicitly. Language should state: "M1 is a dual-deployment data pipeline. The same codebase runs in two configurations: Duo Wealth (local, supplemented by personally-licensed FRD and IBKR feeds) and DataDuo (cloud, public-domain sources only). FRD serves as validation benchmark for both deployments; it is not the authoritative source for either."
2. **Blueprint System Purpose section (lines 11-17):** Add a sentence acknowledging that the system produces both an internal trading platform and a public data service from a shared pipeline.
3. **All future documentation:** Language discipline — "pipeline produces X" rather than "DataDuo provides X" or "Duo Wealth uses X." The deployments serve outputs; the pipeline produces them.

---

#### Finding 2: FRD implicitly treated as primary source rather than validator

**Where the drift exists:**
- Session wrap-up document v1.1, throughout Part 4 — discusses MDY/IJR reconstruction as "Duo Wealth solution" and "DataDuo solution" separately, with FRD implicitly assumed as Duo Wealth's primary data
- Handoff document locked decision 3 (S&P 400/600) uses similar framing
- Roadmap Phase 1A (lines 73-108) treats data provider selection as an open question rather than establishing that public-domain sources are primary and FRD is validator

**What's wrong:**
If FRD were the primary source, losing FRD access would break Duo Wealth. Under the locked vision, the pipeline must work independently of FRD; FRD only accelerates bug discovery during Phase B audit. The current documentation language allows a reader to infer FRD dependency that doesn't actually exist.

**Corrected framing:**
The pipeline is the primary source for both deployments. For Duo Wealth, the pipeline ingests from public-domain sources plus FRD (historical) plus IBKR (forward). For DataDuo, only public-domain sources. FRD's role is (a) provide price data for the Duo Wealth warehouse that includes delisted ticker coverage, and (b) serve as validation benchmark to find bugs in the pipeline's independent output.

**Change instructions:**
1. **Blueprint M1 detail section (lines 181-205):** Rewrite to state explicitly that the pipeline is source-agnostic and that FRD is a validator/benchmark, not a source of truth. Add language: "The pipeline ingests price data from multiple sources through a unified adapter interface. No source is authoritative; the pipeline's own corporate action and universe logic produces the research-tier output. FRD, when present, serves as validation benchmark for pipeline accuracy."
2. **Roadmap Phase 1A (lines 73-108):** Replace "Research and select data provider(s)" work item with "Define multi-source price adapter interface" plus "Identify public-domain price sources for Phase A scaffold (Stooq primary, yfinance for gap-fill)."
3. **Blueprint Technology Stack table (lines 663-680):** No longer list a single data provider row. Add row: "Price sources (multi-source) — adapter-based ingestion from Stooq, yfinance, IBKR, FRD; pipeline enrichment is source-agnostic."

---

#### Finding 3: Feature-group framing displaces pipeline-first thinking

**Where the drift exists:**
- Session wrap-up v1.1, Part 5 "Updated DataDuo Feature Group Count" — entire section frames additions as "feature groups" rather than "capability domains the pipeline now covers"
- Handoff document locked decision 1 — lists five stack additions as if they are bolt-on features
- Throughout both documents, the additions are described in DataDuo-product-catalog terms

**What's wrong:**
Features are emergent outputs of the pipeline's ingestion and enrichment work. By framing them as the primary architectural unit, the documentation implicitly positions DataDuo's product catalog as the design driver rather than the pipeline's coverage needs. This is the mechanism that caused Finding 1 (DataDuo displacing pipeline).

**Corrected framing:**
The pipeline covers capability domains (universe, corporate actions, fundamentals, short interest, holdings, insider activity, calendar, macro, lifecycle, sector classification). Each domain has one or more public-domain source implementations. Both deployments benefit from every domain the pipeline covers; what differs is which deployment surfaces which domain to its users.

**Change instructions:**
1. **Handoff document locked decision 1:** Replace "Stack additions (five) — ACCEPTED" heading with "Public-domain capability-domain coverage — ACCEPTED." Reframe each item by the domain it fills, not as a feature. Example: pandas_market_calendars is listed under "Trading calendar domain," N-PORT under "ETF/fund holdings domain," etc.
2. **ADR-003 title:** Must be "Independent Public-Domain Pipeline Architecture" — not "Public-Domain Stack Extensions" as currently proposed.
3. **Blueprint M1 section:** When describing the pipeline's responsibilities, list capability domains (universe, corporate actions, lifecycle, fundamentals, etc.), not feature groups.

---

#### Finding 4: Missing instrument lifecycle registry in M1

**Where the drift exists:**
- Blueprint M1 detail (lines 181-205): single one-line mention of "delistings" buried in a list of corporate actions
- Blueprint System Tree (line 70-73): M1d Universe Manager has no lifecycle sub-component
- Roadmap Phase 1A (lines 84-107): no work item for lifecycle tracking

**What's wrong:**
Gemini's critique was correct in substance even if incomplete in diagnosis. The pipeline must independently track listing status, delisting, ticker reuse, corporate identity continuity — from public-domain sources — because DataDuo cannot depend on FRD's delisted ticker coverage. Without this, the pipeline produces survivorship-biased output by default.

**Corrected framing:**
Instrument lifecycle is a first-class M1 responsibility. The lifecycle registry tracks every ticker's states (active, delisted, acquired, renamed, suspended) with dated transitions, sourced from public-domain inputs (SEC Form 25 delisting filings, 8-K Item 3.01 delisting notifications, OpenFIGI lifecycle metadata, EDGAR CIK history, historical ETF holdings snapshots). Point-in-time universe queries return the instruments active on the queried date, not currently active.

**Change instructions:**
1. **Blueprint System Tree M1 section (after line 73):** Add new sub-module entry:
   ```
   └── M1f  Instrument Lifecycle Registry (listing/delisting dates, reasons,
             ticker reuse handling, corporate identity continuity, point-in-time
             universe membership queries, sourced from SEC Form 25, 8-K Item 3.01,
             OpenFIGI, EDGAR CIK history, historical ETF holdings snapshots)
   ```
2. **Blueprint M1 Responsibilities list (lines 192-200):** Add bullet: "Track instrument lifecycle — listing, delisting, ticker reuse, corporate identity continuity — as an active registry with point-in-time query support."
3. **Create new module spec file when M1 built:** `modules/m01f-lifecycle-registry.md` detailing the sources, schema, reconciliation logic, and query interface.
4. **Roadmap Phase 1A (lines 84-107):** Add work items for lifecycle registry build, sequenced before price ingestion work.

---

#### Finding 5: No multi-source price adapter pattern in M1

**Where the drift exists:**
- Blueprint M1 detail (lines 181-205): language assumes a single data provider selected at build time
- Blueprint Technology Stack (lines 663-680): lists "Data Storage" but no concept of multi-source price ingestion
- Roadmap Phase 1A (lines 86-88): work items describe "provider API → raw store" implying singular source

**What's wrong:**
The locked vision requires the pipeline to accept multiple price sources and enrich them uniformly. DataDuo's "build your own warehouse" value proposition depends on users bringing their own price sources and having the pipeline enrich them. Duo Wealth depends on having FRD for historical and IBKR for forward feed simultaneously. Current documentation doesn't support multi-source ingestion.

**Corrected framing:**
M1 has an explicit adapter layer. Each price source implements a common adapter interface that normalizes the source's output to a canonical schema with provenance metadata. The pipeline's enrichment logic runs identically against any adapter's output. New sources can be added without touching pipeline logic.

**Change instructions:**
1. **Blueprint System Tree M1 section (after the new M1f from Finding 4):** Add new sub-module:
   ```
   └── M1g  Price Source Adapter Layer (pluggable adapters for Stooq, yfinance,
             IBKR, FRD, user-provided CSV; normalize to canonical schema with
             data provenance metadata; pipeline enrichment is adapter-agnostic)
   ```
2. **Blueprint M1 Responsibilities list:** Add bullet: "Multi-source price ingestion via adapter pattern — pipeline enrichment logic operates identically against any normalized price source."
3. **Create new cross-cutting contract when M1 built:** `contracts/price-source-adapter.md` defining the adapter interface.
4. **Roadmap Phase 1A:** Replace single-provider work items with adapter interface definition + Stooq adapter (primary Phase A scaffold) + yfinance adapter (gap-fill) + IBKR adapter (forward feed) + FRD adapter (Phase B validation).

---

#### Finding 6: No cross-source reconciliation engine in M1

**Where the drift exists:**
- Blueprint M1e Data Quality Validator (line 71-73) mentions "cross-source comparison" as one of several validation checks — but this is single-line and under-specified
- No architectural mechanism described for actively reconciling when multiple sources disagree

**What's wrong:**
The three-warehouse validation protocol depends on being able to reconcile sources systematically. Without a dedicated reconciliation engine, the pipeline cannot produce the measured accuracy deltas that are the basis for DataDuo's Comparative Truth Engine deliverable.

**Corrected framing:**
Reconciliation is its own subsystem within M1. It operates on: (a) the same data point from multiple sources (e.g., AAPL close on 2020-06-15 from Stooq vs IBKR vs FRD), (b) derived values vs source values (e.g., pipeline's calculated adjusted price vs source-provided adjusted price), (c) universe membership across sources (e.g., MDY N-PORT vs FRD constituency data). Discrepancies are flagged, scored for severity, and either auto-resolved by pipeline rules or gated for human review.

**Change instructions:**
1. **Blueprint System Tree M1 section (after M1g from Finding 5):** Add new sub-module:
   ```
   └── M1h  Data Reconciliation Engine (cross-source comparison across price,
             corporate actions, universe membership; confidence scoring per
             source per domain; discrepancy tracking and resolution logic;
             feeds into Data Quality Validator for downstream gating)
   ```
2. **Blueprint M1e Data Quality Validator:** Update language to clarify that M1e consumes M1h's output as one of its validation inputs.
3. **Create new module spec when built:** `modules/m01h-reconciliation-engine.md`.
4. **Create new cross-cutting contract:** `contracts/reconciliation-report-schema.md` defining the discrepancy record format.

---

#### Finding 7: "Bootstrap once, maintain forever" under-scoped

**Where the drift exists:**
- Session wrap-up v1.1, Part 4 — the principle is described but only applied to universe registry
- Blueprint Architectural Principles (lines 19-46) — lists eight principles but does not include this one
- Principle is missing from the foundational architectural document

**What's wrong:**
This principle applies to the entire pipeline, not a subsystem. It is what makes the two-deployment architecture economically viable — ingesting from public-domain sources that publish indefinitely means forward maintenance approaches zero after the historical bootstrap. It should be elevated to a blueprint-level architectural principle.

**Corrected framing:**
Principle 9 (new): "Pipeline is bootstrap-once, maintain-forever. Every data source the pipeline depends on must publish continuously on a predictable schedule without human intervention. This is what makes the two-deployment architecture viable long-term — forward maintenance after historical bootstrap is automated ingestion of already-scheduled public releases. Any source that requires manual intervention to keep updated is rejected or demoted to validation-only role."

**Change instructions:**
1. **Blueprint Architectural Principles section (after line 45):** Add as Principle 9.
2. **Blueprint M1 section:** Add explicit statement that the principle applies to M1 specifically and justifies the source selection criteria.

---

### PARTIAL DRIFT — Reframe, Not Rebuild

---

#### Finding 8: Five stack additions correctly identified but framed as feature additions

**Where the drift exists:**
Handoff document locked decision 1, Session wrap-up v1.1 Part 2

**What's wrong:**
The findings themselves (pandas_market_calendars, datasets/s-and-p-500-companies, FINRA, N-PORT, 13F+Insider) are correct. The framing positions them as DataDuo feature additions rather than as pipeline capability domain coverage.

**Change instructions:**
See Finding 3 change instructions. Reframe each as the capability domain it fills. No content changes; framing changes only.

---

#### Finding 9: S&P 400/600 solution correctly identified but mis-positioned

**Where the drift exists:**
Session wrap-up v1.1 Part 4, Handoff document locked decision 3

**What's wrong:**
MDY/IJR reconstruction via N-PORT + prospectus filings is the correct solution. But it's framed as a workaround specific to the S&P 400/600 index problem rather than as the pipeline's native universe reconstruction method.

**Corrected framing:**
ETF-holdings-based universe reconstruction from SEC filings is how the pipeline natively represents index membership for any index tracked by an SEC-registered ETF. S&P 400 via MDY, S&P 600 via IJR, Russell variants via IWM/IWB/IWV (if scope expands), etc. It is pipeline architecture, not gap workaround.

**Change instructions:**
1. **Blueprint M1 section:** Describe ETF-holdings reconstruction as the pipeline's native method for index membership tracking where an SEC-registered ETF exists. fja05680 + datasets/s-and-p-500-companies serve the same role for S&P 500 (where community-maintained sources are well-established).
2. **Handoff document locked decision 3:** Reframe as "Universe reconstruction methodology locked" — covers S&P 500 via community sources and S&P 400/600 via ETF filings as native pipeline capabilities, not as two separate gap solutions.

---

#### Finding 10: FRED positioning architecturally inconsistent with single-pipeline principle

**Where the drift exists:**
Handoff document locked decision 2, Session wrap-up v1.1 Part 3

**What's wrong:**
"FRED for Duo Wealth internal, direct primary sources for DataDuo" violates the one-codebase principle. If the pipeline is truly one codebase, it ingests from the same sources for both deployments.

**Corrected framing:**
The pipeline ingests from Treasury Fiscal Data, BLS, BEA as primary macro sources. FRED/ALFRED serves as a cross-check/reconciliation source (second opinion) because ALFRED's vintage data adds genuine validation value. Both deployments receive the same ingestion output. FRED is not a deployment-specific convenience layer; it is a reconciliation source.

**Change instructions:**
1. **Handoff document locked decision 2:** Rewrite to state: "Macro source architecture — Primary: Treasury Fiscal Data, BLS, BEA (direct ingestion for both deployments). Reconciliation/cross-check: FRED/ALFRED (same ingestion for both deployments, used to validate primary source ingestion accuracy). Neither deployment treats FRED as authoritative; both deployments receive identical pipeline output."
2. **Blueprint M1 section:** Describe macro ingestion consistently with this framing.

---

### CORRECT — Do Not Change

These items from prior sessions are architecturally aligned and do not need rework:

- **M1 Phase A1/A2/A3 sub-phase split** — sequencing is correct (Finding 14 sharpens it further but the split itself is sound)
- **Single ticker (AAPL) as first reproducible result** — aligned with Blueprint Principle #7
- **ADR-003 as new ADR (not amendment)** — correct structurally, title must change per Finding 3
- **No price serving on DataDuo** — architecturally locked and documented
- **Legal framing caution for ETF-holdings serving** — correctly captured
- **IP attorney consultation as DataDuo pre-launch prerequisite** — correctly captured
- **Universe scope limited to S&P 500 + S&P 400 for v1** — unchanged
- **Blueprint architectural tiers (Tier 1-4)** — unchanged
- **Blueprint architectural principles 1-8** — unchanged (Principle 9 added per Finding 7)
- **Dismissal of Gemini's IBKR latency concern** — correct (EOD scope makes this irrelevant)
- **Dismissal of Gemini's GDPR concern** — correct (Duo Wealth is personal use, DataDuo serves enrichment not user data)

---

### NEW SCOPE — Added by Vision Clarification

These items are not drift fixes. They are net-new scope identified through the architectural discussion that must be added to documentation.

---

#### Finding 11: Three-warehouse validation protocol is new scope

**What it is:**
The Phase B validation methodology (Part 1.4 above) describing three parallel warehouses (DataDuo, Duo Wealth, Test) and strategy backtest comparison across all three.

**Why it's new scope:**
Previous documentation specified "validate pipeline against FRD" but did not specify the three-warehouse triangulation that produces measurable accuracy claims. This is the methodological basis for DataDuo's Comparative Truth Engine deliverable.

**Change instructions:**
1. **Create new cross-cutting contract:** `contracts/validation-protocol.md` documenting the three-warehouse methodology, warehouse definitions, validation sequence, and tolerance specifications.
2. **Roadmap Phase 1B/Phase 2:** Add work items for the reference backtest suite and comparative scorecard generation.
3. **Blueprint:** Add reference to the validation protocol contract in M4 (Backtest Engine) and M5 (Metrics & Grading) sections.

---

#### Finding 12: Three-part DataDuo product is new scope

**What it is:**
The clarification that DataDuo is three deliverables (enrichment API + warehouse-building methodology + comparative truth engine), not just an enrichment API.

**Why it's new scope:**
Previous documentation described DataDuo as an API service. The full vision includes retail education content and ongoing comparative accuracy publishing, both of which require documentation, infrastructure, and ongoing effort.

**Change instructions:**
1. **Blueprint System Purpose section (lines 11-17):** Extend to describe the two deployments and the three-part DataDuo product.
2. **Roadmap:** Add DataDuo launch phase that includes all three deliverables, not just API deployment.
3. **Create new research topic file:** `research/topics/dataduo-product-scope.md` documenting the three-part product definition and rationale.

---

#### Finding 13: Data provenance metadata is first-class pipeline output

**What it is:**
Every data point in the pipeline carries metadata identifying its source, ingestion timestamp, adjustment state when received, transformations applied, and confidence score.

**Why it's new scope:**
The three-warehouse validation protocol and the multi-source adapter pattern both depend on being able to trace every value back to its source and transformation chain. Current documentation treats this implicitly; it needs explicit architectural status.

**Change instructions:**
1. **Blueprint M1 Responsibilities:** Add bullet: "Maintain data provenance metadata for every value — source identity, ingestion timestamp, adjustment state received, transformations applied by pipeline, confidence score."
2. **Blueprint Cross-Cutting Contracts section (lines ~547-598 in source):** Add new contract `contracts/data-provenance-schema.md` defining the provenance record format.

---

#### Finding 14: Phase 1A must be re-sequenced to universe-and-lifecycle-first

**What it is:**
Previous Phase 1A sequencing (per handoff document) was: A1 single ticker end-to-end, A2 S&P 500 scale-up, A3 multi-source reconciliation. This needs adjustment.

**Why it's new scope:**
The locked vision (Part 1.5) requires universe and lifecycle registry to be built before price ingestion. The current A1/A2/A3 sequence does not reflect this — it starts with a single ticker's prices, not with the universe registry.

**Corrected Phase 1A sequence:**
- **A1 — Universe and Lifecycle Foundation (2-3 weeks):** Build lifecycle registry from public-domain sources. Build index membership history (fja05680, datasets/s-and-p-500-companies, MDY/IJR N-PORT). Reconcile and produce the authoritative "every ticker, every index, every lifecycle transition 2005-present" dataset. No prices yet.
- **A2 — Single-Ticker Price Pipeline (1-2 weeks):** Pick one ticker (AAPL recommended). Build price source adapter interface. Implement Stooq adapter. Ingest AAPL price history through adapter → canonical store → research tier with pipeline-applied adjustments. Validate the enrichment logic works end-to-end on one ticker.
- **A3 — Scale and Multi-Source (2-3 weeks):** Expand to full universe coverage. Add yfinance adapter for gap-fill. Add IBKR adapter for forward feed. Build reconciliation engine. Build data_quality gating of downstream publishing.

Total Phase 1A: 5-8 weeks realistic.

**Change instructions:**
1. **Roadmap Phase 1A section (lines 73-108):** Rewrite entirely with the corrected A1/A2/A3 sequence above.
2. **Handoff document:** Update the locked Phase 1A decomposition to match.
3. **Blueprint M1:** Ensure the module description supports this sequencing (universe/lifecycle before prices).

---

## Part 3 — Document-by-Document Change List

This section consolidates all changes per document for efficient execution.

### Blueprint (v0.3 → v0.4)

**Critical changes:**

1. **System Purpose section (lines 11-17)** — Extend to describe two-deployment architecture and three-part DataDuo product (Findings 1, 12)

2. **Architectural Principles (add after line 45)** — Add Principle 9: "Pipeline is bootstrap-once, maintain-forever" (Finding 7)

3. **System Tree M1 section (lines 66-73)** — Add three new sub-modules:
   - M1f Instrument Lifecycle Registry (Finding 4)
   - M1g Price Source Adapter Layer (Finding 5)
   - M1h Data Reconciliation Engine (Finding 6)

4. **Module Detail M1 section (lines 181-205)** — Rewrite substantially:
   - Prepend two-deployment architecture statement (Finding 1)
   - Add source-agnostic and FRD-as-validator language (Finding 2)
   - Expand Responsibilities list with lifecycle tracking, multi-source adapter, provenance metadata (Findings 4, 5, 13)
   - Describe ETF-holdings universe reconstruction as native pipeline method (Finding 9)
   - Describe macro source architecture consistently (Finding 10)

5. **Cross-Cutting Contracts section** — Add three new contracts:
   - `contracts/price-source-adapter.md` (Finding 5)
   - `contracts/reconciliation-report-schema.md` (Finding 6)
   - `contracts/validation-protocol.md` (Finding 11)
   - `contracts/data-provenance-schema.md` (Finding 13)

6. **Technology Stack table (lines 663-680)** — Update:
   - Replace single "Data Storage" entry with multi-source adapter description
   - Add pandas_market_calendars row
   - Keep PostgreSQL 16 + Parquet + DuckDB (ADR-001)

7. **Open Questions section (lines 684-693)** — Remove:
   - "Data provider selection and budget" (settled — multi-source adapter pattern)
   - "Asset class scope for v1" (settled — US equities/ETFs, S&P 500 + S&P 400)

**Version bump:** v0.3 → v0.4
**Changelog entry:** "v0.4 — Added two-deployment pipeline architecture statement. Added Principle 9 (bootstrap-once, maintain-forever). Added M1f (Lifecycle Registry), M1g (Price Source Adapter Layer), M1h (Reconciliation Engine). Expanded M1 detail section for source-agnostic ingestion, ETF-holdings universe reconstruction, multi-source adapter pattern. Added four new cross-cutting contracts (price-source-adapter, reconciliation-report-schema, validation-protocol, data-provenance-schema). Updated Technology Stack. Removed settled open questions."

---

### Roadmap (v1.0.1 → v1.1)

**Critical changes:**

1. **Phase 1A section (lines 73-108)** — Rewrite entirely with universe-and-lifecycle-first sequencing (Finding 14):
   - A1: Universe and Lifecycle Foundation (2-3 weeks)
   - A2: Single-Ticker Price Pipeline (1-2 weeks)
   - A3: Scale and Multi-Source Coverage (2-3 weeks)
   - Total: 5-8 weeks

2. **Add First Reproducible Result Milestone** between Phase 1A and Phase 1B:
   - AAPL end-to-end through M1 → M4 → M5 → M6
   - Reproducible from manifest
   - Gate before Phase 1B

3. **Phase 1B section (lines 112+)** — Add reference backtest suite work items (Finding 11):
   - Design standardized reference strategies
   - Build comparative scorecard infrastructure (feeds Phase B validation)

4. **Add Phase B Validation section** between Phase 1 and Phase 2:
   - Three-warehouse build (DataDuo, Duo Wealth, Test)
   - Run reference strategies across all three
   - Compare scorecards, measure deltas, document tolerances
   - FRD one-month update window used as live validation

5. **Phase C (enrichment expansion)** — Reframe scope from "feature group additions" to "capability domain expansion":
   - Short interest domain (FINRA)
   - ETF/fund holdings domain (N-PORT)
   - Institutional holdings domain (13F)
   - Insider activity domain (Forms 3/4/5)
   - Direct macro primary sources (Treasury/BLS/BEA)

6. **DataDuo launch phase** — Expand to include all three deliverables:
   - Enrichment API deployment
   - "Build your own warehouse" documentation/guide
   - Comparative Truth Engine (ongoing published comparison)
   - IP attorney consultation as prerequisite

7. **Open Questions / Blocked-Waiting table** — Remove:
   - Data provider selection (settled — multi-source adapter)
   - S&P 400 constituency (settled — ETF-holdings reconstruction)
   Add:
   - DataDuo IP attorney consultation (blocks DataDuo go-live)

8. **Recently Completed table** — Add entries:
   - 2026-04-18: Data landscape review v2 + S&P 400/600 deep research
   - 2026-04-19: Architectural audit — two-deployment pipeline, three-warehouse validation, lifecycle registry, multi-source adapter pattern locked

**Version bump:** v1.0.1 → v1.1

---

### Documentation & Knowledge Architecture Plan (v1.1 → v1.2)

**Changes:**

1. **ADR inventory table** — Add ADR-003 row: "ADR-003: Independent Public-Domain Pipeline Architecture — Accepted 2026-04-19"

2. **Contract inventory table** — Add four new contracts:
   - price-source-adapter.md
   - reconciliation-report-schema.md
   - validation-protocol.md
   - data-provenance-schema.md

3. **Module spec inventory** — Add three new module specs tied to M1:
   - modules/m01f-lifecycle-registry.md (Phase 1A-A1 deliverable)
   - modules/m01g-price-source-adapters.md (Phase 1A-A2 deliverable)
   - modules/m01h-reconciliation-engine.md (Phase 1A-A3 deliverable)

**Version bump:** v1.1 → v1.2

---

### New Documents to Create

**ADR:**
- `adrs/ADR-003-independent-public-domain-pipeline-architecture.md` (NEW)
  - Title change from earlier proposal (was "Public-Domain Stack Extensions")
  - Scope: two-deployment architecture, FRD-as-validator, multi-source adapter pattern, lifecycle registry requirement, capability domain coverage
  - Reference ADR-002 as foundation

**Research topics:**
- `research/topics/sp-400-600-constituency-reconstruction.md` (NEW) — per prior handoff instruction, reframed per Finding 9
- `research/topics/data-landscape-review-april-2026.md` (NEW) — per prior handoff instruction
- `research/topics/dataduo-product-scope.md` (NEW) — per Finding 12
- `research/topics/three-warehouse-validation-protocol.md` (NEW) — per Finding 11

**Contracts:**
- `contracts/price-source-adapter.md` (NEW) — per Finding 5
- `contracts/reconciliation-report-schema.md` (NEW) — per Finding 6
- `contracts/validation-protocol.md` (NEW) — per Finding 11
- `contracts/data-provenance-schema.md` (NEW) — per Finding 13

Note: Module specs (m01f, m01g, m01h) get written during the respective Phase 1A sub-phases when those modules are built, not during the documentation update session.

---

## Part 4 — Execution Order for Next Session

To minimize rework during the documentation update session, execute in this order:

1. **Write ADR-003** (authoritative source — other docs reference it)
2. **Write the four new research topic files** (support ADR-003 evidence base)
3. **Write the four new cross-cutting contracts** (referenced by Blueprint updates)
4. **Update Blueprint v0.3 → v0.4** (reference ADR-003 and new contracts)
5. **Update Roadmap v1.0.1 → v1.1** (most care needed for Phase 1A rewrite)
6. **Update Documentation Architecture Plan v1.1 → v1.2** (smallest change, do last)
7. **Atomic commit of all changes** (documents cross-reference and should be consistent)

---

## Part 5 — What Must Not Happen During Next Session

Explicit stop list:

1. **Do not start M1 coding.** Documentation must be consistent first.
2. **Do not re-open the locked decisions in ADR-001 or ADR-002.** ADR-003 extends; it does not supersede.
3. **Do not re-scope Phase 1A sequence after it's written.** The universe-and-lifecycle-first principle is locked per Finding 14.
4. **Do not add additional capability domains beyond those identified in Finding 3.** The fourteen covered domains are the v1 scope. Phase C expansion happens after Duo Wealth is validated.
5. **Do not expand universe beyond S&P 500 + S&P 400 for v1.** Russell expansion is deferred.
6. **Do not substitute any feature-first language for pipeline-first language.** The framing discipline is the mechanism that prevents the drift that caused this audit.

---

## Part 6 — Guardrails Going Forward

To prevent recurrence of the drift pattern that caused this audit, enforce these tests on every future documentation update:

**Test 1: "If I remove FRD, does this still work?"**
- If answer is no, documentation has drifted back to FRD-as-primary.

**Test 2: "Is this pipeline-first or feature-first language?"**
- Phrases like "feature groups," "capabilities," "additions" are red flags.
- Correct phrasing: "the pipeline covers domain X" or "the pipeline produces output Y."

**Test 3: "Does this assume a single data source?"**
- Phrases like "the data source," "the provider" are red flags.
- Correct phrasing: "price sources," "any adapter," "multi-source."

**Test 4: "Does this preserve the hierarchy?"**
- Correct order: Pipeline → Enrichment → Deployment (Duo Wealth / DataDuo) → Outputs
- Any inversion is drift.

**Test 5: "Did I simplify something structural to make the document cleaner?"**
- Compression for narrative flow is the mechanism that caused this audit.
- When in doubt, keep the architectural precision even if it reads slightly rougher.

---

## Part 7 — Summary Verdict

**Before this audit:** Documentation was 70-80% architecturally correct. Drift had accumulated across recent sessions in a way that subtly displaced DataDuo from parallel deployment to downstream consumer, implicitly elevated FRD from validator to primary source, and framed capability domains as feature additions rather than pipeline coverage.

**After executing this audit's documentation changes:** Documentation will be architecturally aligned with the locked vision. The pipeline is explicitly the product. Deployments are explicitly parallel. FRD is explicitly a validator. Multi-source ingestion is explicitly first-class. Lifecycle tracking is explicitly first-class. The three-warehouse validation protocol is explicitly the accuracy methodology.

**Build-readiness:** Not ready to build before documentation updates. Ready to build after — specifically, Phase 1A-A1 (Universe and Lifecycle Foundation) is the first code work, not single-ticker price ingestion.

---

## Part 8 — Instructions for Executing Session (Claude Desktop or Equivalent)

**This section is addressed directly to the assistant executing the documentation updates.** Read it before touching any file.

### Your role in this session

You are executing a locked work order. The architectural decisions in Part 1 are not up for re-examination. Sam (the human in this project) and a prior Claude session (Opus 4.7) produced this audit through extensive cross-session review including external skeptical feedback from Gemini and GPT. The findings are locked.

**Your job is execution, not design.** Read Part 1 carefully, then work through Part 3's change list document-by-document in the order specified in Part 4. Write what the audit specifies. Do not improve it. Do not compress it. Do not make it "cleaner." The framing is deliberate.

### Rules you must follow

**Rule 1: Read Part 1 before each document you edit.**
Part 1 states the locked architectural vision. Every document you produce must be measured against it. Before you start editing a given document, re-read Part 1. This takes 30 seconds and prevents drift.

**Rule 2: Do not rewrite findings in your own words.**
When the audit says "prepend this paragraph" or "add this bullet," use the language given. If the audit's language is structurally important (Findings 1, 2, 3 are all about language discipline), paraphrasing defeats the purpose. When Part 3 says "replace X with Y," use Y verbatim unless the content obviously needs to be adapted to fit a specific document context.

**Rule 3: Do not "fix" things outside the audit scope.**
You will notice issues in the existing documents that aren't in the audit's change list. Do not fix them. Do not "improve" unrelated sections because you're in the file anyway. If you find something genuinely broken that isn't covered, note it at the end of your work for the next architectural session to review. Scope creep during execution is how drift accumulates.

**Rule 4: Verify each file after writing.**
After creating or editing a file, read it back. Confirm the edit landed correctly. Confirm line counts are reasonable (a research topic file should be 800-2,000 words, a contract 500-1,500 words, an ADR 300-800 words — per the Documentation Architecture Plan).

**Rule 5: Pass the five guardrail tests before committing.**
Part 6 defines five tests. Run them mentally on every document you produce:
- If I remove FRD, does this still work? (Must be yes.)
- Is this pipeline-first or feature-first language? (Must be pipeline-first.)
- Does this assume a single data source? (Must not.)
- Does this preserve the hierarchy Pipeline → Enrichment → Deployment → Outputs? (Must.)
- Did I simplify something structural to make the document cleaner? (Must not.)

If any test fails on a document you've written, fix the document before moving on. Do not commit until all five tests pass on all documents in the change set.

**Rule 6: Commit atomically.**
The documents cross-reference each other. Blueprint v0.4 references ADR-003. Roadmap v1.1 references the new contracts. Documentation Plan v1.2 references the new module specs. These must all be consistent at any point a human reads the repo. One commit for the whole batch.

**Rule 7: If you find a genuine contradiction, stop and escalate.**
If executing the audit would require contradicting ADR-001, ADR-002, or any locked decision — stop. Do not resolve it yourself. Document the contradiction clearly and surface it for a future architectural session. Sam's role is to catch drift; yours is to execute cleanly. A contradiction means something upstream needs re-thinking, and that's not what this session is for.

**Rule 8: Commit message discipline.**
Reference the audit document in your commit message. Example:

```
docs: Execute architectural audit dated 2026-04-19

Implements all documentation changes specified in
System_Audit_And_Documentation_Update_Plan_April_2026.md

New documents:
- ADR-003 (Independent Public-Domain Pipeline Architecture)
- 4 research topic files
- 4 cross-cutting contracts

Updated documents:
- Blueprint v0.3 → v0.4
- Roadmap v1.0.1 → v1.1
- Documentation Architecture Plan v1.1 → v1.2

All guardrail tests (Part 6) verified before commit.
```

### What the audit expects you to produce

Refer to Part 9 (Completion Checklist) for the explicit deliverable list. You are done when every item in Part 9 is checked.

### What success looks like

After you commit, a human reading the updated documentation should find:
- The pipeline explicitly described as the product, with Duo Wealth and DataDuo as parallel deployments
- FRD explicitly described as a validator, not a primary source
- Lifecycle registry, price source adapter, reconciliation engine all specified in M1
- The three-warehouse validation protocol documented in a dedicated contract
- Phase 1A re-sequenced as universe-and-lifecycle-first
- All new capability domains reframed away from "feature group" language
- Nothing in the existing correct content disturbed

---

## Part 9 — Completion Checklist

Work through these in order. Check each as you complete it. Do not commit until every item is checked.

### Stage 1: New Documents (Execute Part 4 steps 1-3)

**ADR:**
- [ ] `docs/adrs/ADR-003-independent-public-domain-pipeline-architecture.md` created
  - Status: Accepted, Date: 2026-04-19
  - References ADR-002 as foundation
  - Covers: two-deployment architecture, FRD-as-validator, multi-source adapter, lifecycle registry, capability domain coverage

**Research topic files:**
- [ ] `docs/research/topics/sp-400-600-constituency-reconstruction.md` created
- [ ] `docs/research/topics/data-landscape-review-april-2026.md` created
- [ ] `docs/research/topics/dataduo-product-scope.md` created (three-part product definition)
- [ ] `docs/research/topics/three-warehouse-validation-protocol.md` created

**Cross-cutting contracts:**
- [ ] `docs/contracts/price-source-adapter.md` created
- [ ] `docs/contracts/reconciliation-report-schema.md` created
- [ ] `docs/contracts/validation-protocol.md` created
- [ ] `docs/contracts/data-provenance-schema.md` created

### Stage 2: Blueprint Update (Execute Part 4 step 4)

- [ ] System Purpose section extended (two-deployment + three-part DataDuo product)
- [ ] Principle 9 added ("Pipeline is bootstrap-once, maintain-forever")
- [ ] System Tree M1 section adds M1f (Lifecycle Registry), M1g (Price Source Adapter Layer), M1h (Reconciliation Engine)
- [ ] Module Detail M1 section rewritten per Finding 1, 2, 4, 5, 9, 10, 13 instructions
- [ ] Cross-Cutting Contracts section references the four new contracts
- [ ] Technology Stack table updated (multi-source adapters, pandas_market_calendars added)
- [ ] Open Questions updated (data provider selection and asset class scope removed as settled)
- [ ] Version bumped v0.3 → v0.4 with changelog entry

### Stage 3: Roadmap Update (Execute Part 4 step 5)

- [ ] Phase 1A rewritten with A1 (Universe/Lifecycle Foundation), A2 (Single-Ticker Price Pipeline), A3 (Scale/Multi-Source) sequencing
- [ ] First Reproducible Result Milestone section added between Phase 1A and 1B
- [ ] Phase 1B work items added for reference backtest suite
- [ ] Phase B Validation section added (three-warehouse build, comparative scorecards, FRD free-month window)
- [ ] Phase C reframed from "feature group additions" to "capability domain expansion"
- [ ] DataDuo launch phase expanded to cover all three deliverables (API + methodology + comparative truth engine)
- [ ] IP attorney consultation added as DataDuo launch prerequisite
- [ ] Open Questions / Blocked-Waiting table updated (settled items removed, IP consultation added)
- [ ] Recently Completed table updated with 2026-04-18 and 2026-04-19 entries
- [ ] Version bumped v1.0.1 → v1.1 with changelog entry

### Stage 4: Documentation Architecture Plan Update (Execute Part 4 step 6)

- [ ] ADR inventory table adds ADR-003 row
- [ ] Contract inventory table adds four new contracts
- [ ] Module spec inventory adds m01f, m01g, m01h entries (as future Phase 1A deliverables)
- [ ] Version bumped v1.1 → v1.2 with changelog entry

### Stage 5: Verification (Before commit)

- [ ] All new files read back and verified
- [ ] All edited files read back and verified
- [ ] Guardrail Test 1 passed on all documents: removing FRD doesn't break anything
- [ ] Guardrail Test 2 passed on all documents: pipeline-first language throughout
- [ ] Guardrail Test 3 passed on all documents: no single-source assumptions
- [ ] Guardrail Test 4 passed on all documents: hierarchy preserved (Pipeline → Enrichment → Deployment → Outputs)
- [ ] Guardrail Test 5 passed on all documents: no structural simplification for readability
- [ ] Git status reviewed — only intended files modified
- [ ] Git identity configured (user.name, user.email)

### Stage 6: Commit (Execute Part 4 step 7)

- [ ] Single atomic commit created with all changes
- [ ] Commit message references audit document (per Rule 8 format)
- [ ] Commit pushed to remote (if Sam has directed to do so — otherwise leave committed locally for review)

### Stage 7: Handoff Note

- [ ] Summary note produced for Sam documenting:
  - What was completed (reference Part 9 checklist status)
  - Any contradictions or issues escalated (per Rule 7)
  - Any out-of-scope issues noticed for future sessions (per Rule 3)
  - Confirmation that next step is Phase 1A-A1 coding (Universe and Lifecycle Foundation)

---

*Document version: 1.1*
*Created: April 19, 2026*
*Updated: April 19, 2026 — Added Part 8 (executor instructions) and Part 9 (completion checklist) to support handoff to desktop Claude session for execution*
*Status: Audit complete, awaiting documentation update execution*
*Author: Claude Opus 4.7 (HoneyDuo Wealth architect)*
*Next session: Execute documentation updates per Part 3 change list in the order specified in Part 4. Follow Part 8 rules. Complete all items in Part 9. Do not begin coding until all updates committed.*