# DataDuo Product Scope

## Question

What is the complete scope of the DataDuo public deployment's product offering? Is DataDuo an enrichment API, or does its charter extend beyond API service?

## Why It Matters

Prior documentation described DataDuo as an API serving pipeline enrichment outputs. The April 2026 architectural review clarified that DataDuo is three deliverables, not one — and the two deliverables beyond the API each carry infrastructure, documentation, and ongoing-effort commitments that need to be visible in the roadmap and launch planning. Under-scoping DataDuo as "just an API" causes the Build-Your-Own-Warehouse and Comparative Truth Engine commitments to surface late, after engineering decisions have already foreclosed them.

## Sources Reviewed

- ADR-003 (Independent Public-Domain Pipeline Architecture) — locked two-deployment architecture and three-part DataDuo definition
- April 2026 architectural audit Part 1.3 (three-part DataDuo product)
- April 2026 architectural audit Finding 12 (three-part DataDuo as new scope)
- Session wrap-up discussions on DataDuo positioning
- ADR-002 (Data Provider Stack) — DataDuo's redistributable-only source constraint

## Key Findings

**DataDuo serves three deliverables, not one. [Confirmed — architectural decision, ADR-003]**
Per ADR-003, DataDuo's public product is:

1. **Enrichment API** — programmatic access to pipeline outputs across every capability domain except prices: universe membership history, instrument lifecycle, corporate actions, fundamentals, short interest, ETF/fund holdings, institutional holdings, insider activity, trading calendar, macro, sector classification, identifiers, index membership history.
2. **Build-Your-Own-Warehouse methodology** — documentation and guides teaching retail users to combine free price sources (Stooq, yfinance, user CSV) with DataDuo enrichment outputs to construct a backtest-ready warehouse. The methodology is the product; the user runs it on their own infrastructure.
3. **Comparative Truth Engine** — ongoing published comparison measuring the accuracy delta between (a) a free-data-plus-DataDuo-enrichment system and (b) an FRD-assisted system on a standardized reference strategy suite. The honest accuracy delta is the trust anchor that justifies DataDuo's value proposition.

**DataDuo never serves prices. [Confirmed — architectural decision, ADR-003]**
ADR-002 constrains DataDuo to redistributable public-domain sources; none of FRD, IBKR, or paid price providers are eligible for DataDuo serving. ADR-003 extends this: even public-domain price data is not served by DataDuo — users bring their own prices. This is both a legal posture (no dispute over price-data licensing) and an architectural clarity (DataDuo's value is enrichment, not prices).

**Comparative Truth Engine is load-bearing, not marketing. [Confirmed]**
DataDuo's value proposition is "public-domain enrichment close enough to premium that you don't need the premium feed." The Comparative Truth Engine is how that claim is substantiated — it publishes the measured accuracy delta between Warehouse A (free+DataDuo, per ADR-003's three-warehouse protocol) and Warehouse B (FRD+IBKR+pipeline). Without it, DataDuo's value is asserted but not demonstrated.

**Build-Your-Own-Warehouse methodology requires documentation infrastructure. [Strong support]**
The methodology is an external-facing product deliverable: how-to guides, example code, CSV schemas, walkthroughs. It is not "API documentation" — it is teaching content with its own review and maintenance cycle. Scoping it as a deliverable means the DataDuo launch phase includes content creation, not just engineering.

**IP attorney consultation is a prerequisite for DataDuo launch. [Confirmed — tracked as open question #1]**
Serving capability-domain derivatives (ETF-holdings-derived universe, corporate-actions-derived adjustments, etc.) requires legal review of IP positioning before the first paying subscriber. Estimated ~$500 consultation cost; blocks DataDuo go-live.

**Pricing model for DataDuo is unresolved. [Open question]**
Whether DataDuo monetizes via subscription, usage-based API pricing, a freemium tier, or a one-time data-dump model has not been decided. Does not block pipeline build; blocks DataDuo launch.

## Implications

- **Roadmap:** The DataDuo launch phase expands to cover all three deliverables. API engineering alone does not complete DataDuo's v1.
- **Phase B validation:** Directly enables the Comparative Truth Engine — the three-warehouse validation protocol produces the measurement the engine publishes.
- **Documentation:** Build-Your-Own-Warehouse methodology lives under DataDuo's external-facing content, not in the internal `/docs` tree. Internal specs describe how the pipeline produces enrichment outputs; the methodology describes how users consume them.
- **Infrastructure:** Comparative Truth Engine requires ongoing compute (periodic re-running of reference strategies across all three warehouses as new data accumulates) and a publication surface (dashboard, API endpoint, or periodic report).
- **Legal:** IP attorney consultation must occur before the first paying subscriber — this is a hard gate, not a soft recommendation.

## Recommended Decision

Adopt the three-part DataDuo product scope per ADR-003. Reflect in the roadmap as an expanded DataDuo launch phase with three parallel workstreams (API engineering, methodology content, Comparative Truth Engine infrastructure). Gate the phase on IP attorney consultation completion.

No separate ADR needed — ADR-003 encompasses the architectural decision. This research topic documents the rationale and the downstream work.

## Unresolved Questions

- DataDuo pricing model — subscription vs usage-based vs freemium vs one-time
- Comparative Truth Engine publication cadence — daily, weekly, monthly, per-reference-strategy-rerun
- Build-Your-Own-Warehouse distribution channel — GitHub docs site, dedicated documentation portal, or published guide
- IP attorney consultation scope — universe-derivative framing, corporate-actions-derivative framing, enrichment-as-service positioning (open question #1)
