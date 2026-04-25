# ADR-003: Independent Public-Domain Pipeline Architecture

## Status
Accepted

## Date
2026-04-19

## Context

ADR-002 locked a redistributable-friendly provider stack and positioned FirstRateData (FRD) as historical backfill plus validation benchmark. That ADR did not, however, formalize the architectural consequences of that positioning. Across recent session wrap-ups and handoff notes, documentation drifted in three directions incompatible with the spirit of ADR-002:

1. DataDuo was framed as a downstream consumer of pipeline outputs rather than as a parallel deployment of the pipeline codebase.
2. FRD was implicitly treated as Duo Wealth's primary historical source, such that loss of FRD access would break the deployment.
3. Stack additions (pandas_market_calendars, N-PORT, FINRA, 13F/Forms 3-4-5, direct macro primary sources) were described as DataDuo "feature groups" rather than as capability domains the pipeline now covers.

Separately, a cross-session review surfaced a survivorship and delisting gap: the pipeline had no first-class instrument lifecycle tracking, no native multi-source price ingestion pattern, and no systematic cross-source reconciliation. These absences are symptoms of the same framing drift — they appear when DataDuo's product catalog, not the pipeline's coverage, drives the architecture.

This ADR formalizes the architectural corollaries of ADR-002 so that ADR-002's positioning cannot be re-drifted. It extends ADR-002; it does not supersede it.

## Decision

**The pipeline is the system.** One codebase ingests, enriches, and serves data across a defined set of capability domains. The pipeline is source-agnostic for prices and authoritative for its own enrichment logic.

**Two deployments, one codebase:**

| Deployment | Location | Price sources | Enrichment sources | Serves |
|------------|----------|---------------|--------------------|--------|
| Duo Wealth | Local (Ubuntu workstation) | Stooq + yfinance + IBKR + FRD (personal license) | Pipeline output from public-domain sources | Personal trading research and execution |
| DataDuo | Cloud VPS | Public-domain sources only (Stooq, yfinance, user-provided CSV) | Pipeline output from public-domain sources | Public three-part product: Enrichment API, Build-Your-Own-Warehouse methodology, Comparative Truth Engine — never prices |

**FRD is treated as one adapter among many; the pipeline never trusts FRD's adjustments.** The FRD adapter ingests FRD's data, reverses whatever adjustment state FRD provides back to unadjusted raw, and the pipeline re-applies its own EDGAR-derived adjustment factors. If FRD's adjustments differ from the pipeline's, the pipeline is the truth — same posture the pipeline takes toward Stooq, yfinance, IBKR, FRD, or user-provided CSV. The pipeline functions identically when ingesting from any adapter, so FRD is not a load-bearing dependency for pipeline operation.

FRD plays two distinct roles in the three-warehouse protocol, neither of which is "primary source for pipeline logic":

1. **One-time historical bootstrap source for Warehouse B (Duo Wealth's permanent production warehouse).** The pipeline ingests FRD historical exactly once through the FRD adapter during B's initial bootstrap. After bootstrap, B is maintained forward by IBKR daily ingestion alone. FRD is not in B's operational loop thereafter.
2. **Ongoing comparison reference for Warehouse C (the temporary pipeline-logic-parity arm).** The pipeline ingests fresh FRD data on rolling dates and compares its own enrichment output against FRD's native output. This continues only as long as FRD update access is maintained; Warehouse C is dismantled when that access ends.

FRD does not participate in DataDuo at any layer.

**Multi-source price adapter layer (M1g).** All price sources implement a common adapter interface that normalizes source output to a canonical schema with provenance metadata. Pipeline enrichment runs identically against any adapter's output. Adding a new source does not touch pipeline logic.

**Unadjust-then-re-adjust.** No source is trusted for adjustments. Every adapter reverses whatever adjustment state the source provides back to unadjusted raw; the pipeline then applies its own adjustment factors (derived from EDGAR 8-K Item 5.03 parsing) to produce research-tier adjusted prices. This is what makes the three-warehouse validation meaningful — each warehouse's prices are normalized through identical logic.

**Instrument Lifecycle Registry (M1f) is first-class.** The pipeline independently tracks listing, delisting, ticker reuse, and corporate identity continuity from public-domain sources (SEC Form 25, 8-K Item 3.01, OpenFIGI, EDGAR CIK history, historical ETF holdings snapshots). Point-in-time universe queries return instruments active on the queried date, not currently active. Universe and lifecycle are built before any price ingestion (Phase 1A-A1 before A2).

**Data Reconciliation Engine (M1h).** Cross-source comparison across price, corporate actions, and universe membership, with confidence scoring per source per domain. Reconciliation output feeds the Data Quality Validator (M1e) for downstream gating and is the evidentiary basis for DataDuo's Comparative Truth Engine deliverable.

**Capability domains, not feature groups.** The pipeline covers capability domains — universe, instrument lifecycle, corporate actions, fundamentals, short interest, ETF/fund holdings, institutional holdings, insider activity, trading calendar, macro, sector classification, identifiers, index membership history, data quality. Both deployments benefit from every domain the pipeline covers; what differs is which deployment surfaces which domain to its users.

**Bootstrap-once, maintain-forever.** Every data source the pipeline depends on must publish continuously on a predictable schedule without human intervention. Forward maintenance after historical bootstrap is automated ingestion of already-scheduled public releases. Any source that requires manual intervention to stay current is rejected or demoted to validation-only. This is elevated to a blueprint-level architectural principle (Principle 9) to bind the entire system, not only this ADR's scope.

## Alternatives Considered

**FRD-primary with DataDuo as downstream consumer.** Treat FRD as Duo Wealth's authoritative historical source and build DataDuo as an API that serves a subset of pipeline enrichment. Rejected because (a) it creates a hard dependency on a single vendor whose licensing could change, (b) it prevents source-agnostic validation across the three warehouses, and (c) it displaces the pipeline from its central architectural position. This is precisely the drift pattern the April 2026 architectural audit documented and corrected — see `docs/audits/System_Audit_And_Documentation_Update_Plan_April_2026.md`.

**Single-deployment (DataDuo only, ingest public-domain only, use internally too).** Reject personal-license sources entirely and run one deployment. Rejected because FRD's delisted-ticker coverage and IBKR's execution-venue alignment provide genuine value for personal trading research and for validation that cannot be substituted from public-domain sources alone. The two-deployment split preserves that value without contaminating the public product.

**Feature-group architectural framing.** Organize the pipeline around DataDuo's product catalog (enrichment features) rather than capability domains. Rejected because feature-first framing systematically inverts the architectural hierarchy — DataDuo's product scope becomes the design driver rather than the pipeline's coverage needs — which is the drift pattern documented in the April 2026 audit.

**Single price source per deployment.** Pick one price source per deployment and hard-wire it. Rejected because DataDuo's Build-Your-Own-Warehouse methodology requires users to bring their own price sources through the adapter interface, and Duo Wealth requires simultaneous FRD-historical and IBKR-forward ingestion.

## Consequences

**Enables:**
- Pipeline is genuinely source-agnostic for prices — new sources plug in without touching enrichment logic
- Three-warehouse validation protocol produces measurable accuracy deltas (the evidentiary basis for the Comparative Truth Engine)
- DataDuo's legal posture is clean — no personal-license data is ever served
- Loss of FRD access does not degrade pipeline operation. Before Warehouse B's historical bootstrap completes, it forces fallback to public-domain historical with measurably worse delisted-ticker coverage. After B's bootstrap completes, it has zero operational impact on B (maintained forward by IBKR alone) or A (which never depended on FRD); it ends Warehouse C's specific pipeline-logic-parity comparison, by design — C is a temporary warehouse bounded by FRD update access.
- Lifecycle-first build order eliminates survivorship bias by construction, not as an afterthought

**Constrains:**
- M1 gains three new sub-modules (M1f Lifecycle Registry, M1g Adapter Layer, M1h Reconciliation Engine) that must be built before Phase 1A exit
- Phase 1A sequencing is locked as universe-and-lifecycle-first — single-ticker price work cannot start until A1 completes
- Every price source integration requires implementing the adapter's reverse-adjustment logic, not just passthrough
- Data provenance metadata is mandatory on every value the pipeline produces

**Operational:**
- Universe and lifecycle registries are cold-started from public-domain sources covering 2005–present; forward maintenance is automated ingestion of scheduled public releases (SEC EDGAR, N-PORT, fja05680 updates, datasets/s-and-p-500-companies)
- DataDuo VPS deployment never receives FRD or IBKR data — enforced at the adapter-registration layer
- Three-warehouse builds run in parallel during Phase B validation; tolerance thresholds are measured empirically and recorded in `contracts/validation-protocol.md`
- Warehouse A and Warehouse B persist after Phase B validation completes; Warehouse C is dismantled when FRD update access ends. The Comparative Truth Engine consumes ongoing A-vs-B scorecard deltas indefinitely after Phase B.

**Key risk:**
- Adapter reverse-adjustment logic is the highest-risk component — getting it wrong silently corrupts every downstream value. Mitigated by three-warehouse cross-validation (Warehouses A, B, C must align within measured tolerance), FRD native output as Warehouse C reference, and per-adapter unit tests on known corporate action sequences.

## Revisit If
- A material public-domain source discontinues scheduled publication — bootstrap-once, maintain-forever is the load-bearing assumption for both deployments
- Three-warehouse tolerance thresholds cannot be met after empirical measurement — may indicate unmodeled divergence in adapter logic or a missing capability domain
- DataDuo legal review (IP attorney consultation prerequisite) surfaces a framing problem with ETF-holdings-as-universe-proxy or any other served capability domain
- International expansion becomes priority — capability domains currently assume US-centric source taxonomy (EDGAR, SEC, FINRA)
- FRD pricing or licensing changes materially before Duo Wealth historical bootstrap is complete
