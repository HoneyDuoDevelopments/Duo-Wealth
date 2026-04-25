# S&P 400 / S&P 600 Constituency Reconstruction

## Question

How does the pipeline reconstruct historical constituency for the S&P 400 (mid-cap) and S&P 600 (small-cap) indices, given that no redistributable community-maintained constituency history exists for either index the way fja05680/sp500 does for the S&P 500?

## Why It Matters

Universe coverage without survivorship bias is a load-bearing assumption for every downstream capability in the pipeline. If mid-cap and small-cap universes cannot be reconstructed point-in-time from public-domain sources, then (a) DataDuo cannot serve a trustworthy multi-cap universe, and (b) Warehouse A (the public-domain arm of the three-warehouse validation protocol per ADR-003) cannot test strategies outside S&P 500 without introducing an unmeasured survivorship source. Point-in-time universe membership is the ground truth that price data hangs from; getting it wrong silently invalidates every backtest that touches mid-cap or small-cap strategies.

## Sources Reviewed

- SEC EDGAR N-PORT filings for MDY (SPDR S&P MidCap 400 ETF) and IJR (iShares Core S&P Small-Cap ETF)
- SPDR and iShares prospectus filings (pre-N-PORT era)
- ETF annual and semi-annual reports (Forms N-CSR)
- OpenFIGI lifecycle metadata for ticker resolution
- Historical constituency discussions in buy-side practitioner accounts (Carver, Clenow references)
- Cross-reference: fja05680/sp500 repository (MIT-licensed S&P 500 reference)
- ADR-002 locked provider stack (FRD as validator, SEC EDGAR as primary)

## Key Findings

**MDY and IJR both file N-PORT quarterly with monthly holdings disclosed. [Confirmed]**
The N-PORT rule (effective 2019) requires registered investment companies to report portfolio holdings at month-end with public disclosure 60 days after quarter-end. MDY and IJR both file. The filings are public-domain and redistributable.

**N-PORT covers 2019-present; earlier coverage requires annual/semi-annual report reconstruction. [Strong support]**
Pre-2019 ETF holdings data exists in Form N-CSR semi-annual reports and fund annual reports filed through EDGAR, but at lower frequency (semi-annual vs monthly) and with less structured disclosure. Reconstruction is possible but requires parsing less-standardized report formats.

**ETF holdings as proxy for index membership is architecturally sound within the pipeline. [Confirmed]**
An SEC-registered ETF tracking an index must hold, within tolerance, the index's constituents. ETF holdings on date D approximate index constituency on date D. The delta between ETF holdings and true index membership is bounded by the ETF's sampling methodology and rebalance timing — measurable, not mysterious.

**This method generalizes beyond S&P 400/600. [Confirmed]**
Any index that has an SEC-registered tracking ETF can be reconstructed the same way — Russell indices via IWM/IWB/IWV, MSCI indices via iShares trackers, etc. This is the pipeline's native universe-reconstruction method for ETF-tracked indices, not a workaround specific to S&P 400/600.

**Legal framing for serving ETF-holdings-derived universe requires attorney review. [Open question]**
ETF holdings are public-domain data. Derivatives of those holdings (e.g., "S&P 400 constituency as-of 2021-06-30") may or may not fall within S&P Dow Jones Indices' IP claims when served commercially by DataDuo. Blocks DataDuo launch; does not block Duo Wealth internal use.

**Pre-2019 S&P 400/600 coverage via prospectus reconstruction is feasible but not yet validated. [Needs live validation]**
The reconstruction path exists (N-CSR filings + prospectus updates) but the actual ingestion + parsing logic has not been built or tested. Coverage quality at 2005–2018 is unknown until implementation.

## Implications

- **Pipeline:** ETF-holdings reconstruction is a first-class M1 capability, not a gap workaround. Part of the Instrument Lifecycle Registry (M1f) and Universe Manager (M1d) responsibility set.
- **Phase 1A-A1:** MDY and IJR N-PORT ingestion is a deliverable of the Universe and Lifecycle Foundation sub-phase, sequenced before any price ingestion.
- **Capability domain:** Index membership history is one of the capability domains the pipeline covers; the ETF-holdings method is one of the source implementations for that domain (alongside fja05680 + datasets/s-and-p-500-companies for S&P 500).
- **DataDuo serving:** Serving ETF-holdings-derived universe membership is gated on IP attorney consultation (open question #1).
- **Warehouse B vs C:** FRD provides a validation benchmark for pipeline-reconstructed constituency; Warehouse C's "pipeline logic matches FRD's native output when given the same underlying data" test exercises the reconstruction against FRD's own constituency records.

## Recommended Decision

Adopt ETF-holdings reconstruction (MDY for S&P 400, IJR for S&P 600) as the pipeline's native method for these indices. Document as a capability in the M1f Lifecycle Registry module spec when M1f is built during Phase 1A-A1. No dedicated ADR needed — this decision is encompassed by ADR-003 (Independent Public-Domain Pipeline Architecture), which establishes capability-domain coverage and public-domain source preference.

Pre-2019 coverage extension via N-CSR and prospectus reconstruction is deferred to Phase 1A-A3 or later; Phase 1A-A1 targets 2019–present as the minimum viable S&P 400/600 coverage.

## Unresolved Questions

- Pre-2019 S&P 400/600 coverage quality — feasible via N-CSR but needs live validation during A1/A3
- IP attorney framing for serving ETF-holdings-derived universe via DataDuo — tracked as open question #1
- Russell index reconstruction (IWM/IWB/IWV) — deferred to v2 per existing open question #3
- Tolerance threshold between ETF holdings and true index constituency — measured empirically during reconciliation (M1h)
