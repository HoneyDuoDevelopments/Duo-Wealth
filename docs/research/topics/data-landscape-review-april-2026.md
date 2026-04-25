# Data Landscape Review — April 2026

## Question

Is the provider stack locked in ADR-002 (FRD, IBKR, SEC EDGAR, OpenFIGI, FRED/ALFRED, fja05680) complete for the pipeline's v1 capability-domain coverage, or are there capability domains the pipeline must add sources for before Phase 1A build begins?

## Why It Matters

ADR-003 formalizes the pipeline as covering a defined set of capability domains from public-domain sources. A gap in source coverage at ADR-003's acceptance date becomes a gap in the pipeline's v1 scope. Finding it now (pre-build) is cheap; finding it mid-build costs a sub-phase. Additionally, the three-warehouse validation protocol depends on Warehouse A (public-domain-only) being able to produce results across every capability domain the pipeline claims to cover — a capability-domain gap in Warehouse A invalidates the protocol's "public-domain sources are sufficient" claim.

## Sources Reviewed

- SEC EDGAR filing documentation (N-PORT, N-CSR, Forms 3/4/5, 8-K, 10-K/Q, S-1)
- FINRA short-interest bi-monthly reporting documentation
- 13F institutional holdings filing rules and bulk data availability
- OpenFIGI API coverage for identifier mapping and lifecycle events
- pandas_market_calendars package (exchange calendars, NYSE/NASDAQ/LSE/etc.)
- datasets/s-and-p-500-companies (CC0-licensed S&P 500 historical constituents)
- US Treasury Fiscal Data service (direct Treasury bond/bill/note issuance data)
- Bureau of Labor Statistics (BLS) direct API — CPI, PPI, employment
- Bureau of Economic Analysis (BEA) direct API — GDP, NIPA tables
- FRED/ALFRED (Federal Reserve Economic Data + vintage data archive)
- fja05680/sp500 repository (MIT-licensed S&P 500 reference)
- Prior session wrap-ups and handoff documents (April 2026)
- External skeptical feedback (Gemini, GPT cross-session reviews)

## Key Findings

**Trading calendar capability requires a dedicated source. [Strong support]**
Pipeline correctness depends on knowing exchange trading days, half-days, and holiday calendars across markets and history. `pandas_market_calendars` covers NYSE, NASDAQ, CME, LSE, and others with historical accuracy. Public-domain / permissively-licensed. Fills the trading calendar capability domain.

**Short interest capability requires FINRA ingestion. [Strong support]**
FINRA publishes short-interest data bi-monthly (around the 15th and end-of-month settlement dates) for all Reg SHO-eligible securities. Data is public and redistributable. Fills the short-interest capability domain; not covered by any existing ADR-002 source.

**ETF / fund holdings capability requires N-PORT parsing. [Strong support]**
Form N-PORT (effective 2019) provides monthly holdings for registered investment companies, disclosed publicly 60 days after quarter-end. Fills the ETF/fund-holdings capability domain and, by extension, underwrites ETF-holdings-based universe reconstruction per the `sp-400-600-constituency-reconstruction` research topic.

**Institutional holdings capability requires 13F parsing. [Strong support]**
Form 13F is filed quarterly by institutional investment managers with >$100M AUM. Bulk data is available from EDGAR. Fills the institutional-holdings capability domain.

**Insider activity capability requires Forms 3/4/5 parsing. [Strong support]**
Forms 3, 4, and 5 (Section 16 insider filings) are filed via EDGAR for corporate officers, directors, and >10% holders. Structured XBRL is available. Fills the insider-activity capability domain.

**Direct macro primary sources are preferable to FRED as primary; FRED serves reconciliation. [Confirmed]**
Treasury Fiscal Data, BLS, and BEA provide direct, authoritative, public-domain macro data. Ingesting them directly removes FRED's caching layer from the primary path. FRED/ALFRED retains architectural value as a reconciliation cross-check — ALFRED's vintage data lets the pipeline detect when its own macro ingestion has drifted vs. the Fed's archived view. Per ADR-003, both deployments receive identical pipeline output; FRED is not a deployment-specific convenience layer.

**fja05680 + datasets/s-and-p-500-companies are complementary for S&P 500 constituency. [Strong support]**
fja05680 is the long-standing community S&P 500 reference; datasets/s-and-p-500-companies is a CC0-licensed alternative. Cross-reconciliation between them during M1h reconciliation catches errors in either.

**No gap identified in the fundamentals capability domain. [Confirmed]**
SEC EDGAR XBRL covers fundamentals for all US-registered filers. ADR-002's coverage stands.

**No gap identified in identifier mapping. [Confirmed]**
OpenFIGI covers FIGI mapping; EDGAR CIK history covers corporate identity continuity. ADR-002's coverage stands.

**Instrument lifecycle registry is its own capability domain, not a sub-feature of universe management. [Confirmed]**
Sources: SEC Form 25 (delisting), 8-K Item 3.01 (delisting notification), 8-K Item 5.03 (charter/name changes), OpenFIGI (lifecycle metadata), EDGAR CIK history, historical ETF holdings snapshots. Fills the lifecycle capability domain per ADR-003; formalized in M1f.

## Implications

- **Pipeline scope (ADR-003):** Fourteen capability domains in v1 — universe, instrument lifecycle, corporate actions, fundamentals, short interest, ETF/fund holdings, institutional holdings, insider activity, trading calendar, macro, sector classification, identifiers, index membership history, data quality.
- **Source additions (capability-domain framing, not feature additions):**
  - `pandas_market_calendars` — trading calendar domain
  - FINRA bi-monthly short interest — short interest domain
  - SEC N-PORT — ETF/fund holdings domain (also feeds S&P 400/600 universe reconstruction and M1f lifecycle)
  - SEC 13F — institutional holdings domain
  - SEC Forms 3/4/5 — insider activity domain
  - Treasury Fiscal Data + BLS + BEA — direct macro primary; FRED/ALFRED demoted to reconciliation
  - datasets/s-and-p-500-companies — secondary S&P 500 constituency (cross-checks fja05680)
- **Roadmap:** Phase C (enrichment expansion) work items map one-to-one to these capability domains, not to feature groups.
- **ADR-002:** Not superseded. This research extends ADR-002's locked stack with additional public-domain sources; the original sources remain in their original roles. ADR-003 is the ADR that formalizes the extended architecture.

## Recommended Decision

Accept the extended source roster as the v1 pipeline scope per ADR-003. No separate ADR needed for each source — ADR-003 covers the architectural stance (capability-domain-driven public-domain source selection). Module specs written during Phase 1A and Phase C will reference the specific sources for their domains.

Direct macro primary source positioning (Treasury/BLS/BEA primary, FRED reconciliation) is a framing correction per the April 2026 audit Finding 10 — both deployments receive identical pipeline output, FRED is not a deployment-specific convenience layer.

## Unresolved Questions

- Phase C sequencing within capability-domain expansion — which domain first after Phase 1A validates the core pipeline? Likely short interest or ETF/fund holdings, but sequencing can wait until Phase 1B exit.
- Licensing review for N-PORT / 13F derivative serving via DataDuo — rolls up to open question #1 (IP attorney consultation).
- BLS and BEA API rate limits under sustained ingestion — needs live validation during Phase C.
