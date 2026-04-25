# Contract: Price Source Adapter

## Purpose

Defines the interface every price source adapter must implement. Normalizes source-native data to a canonical price record with provenance metadata so that pipeline enrichment runs identically against any adapter's output. Source-agnosticism per ADR-003 depends on strict adherence to this contract.

## Used By

- **M1g** — Price Source Adapter Layer (houses the adapters)
- **M1b** — Canonical Store (consumes adapter output)
- **M1c** — Research Store (applies pipeline adjustments to adapter output)
- **M1h** — Reconciliation Engine (compares multiple adapters' output for the same data point)
- **M1e** — Data Quality Validator (gates downstream publishing on adapter output quality)

## Adapter Identity and Registration

Every adapter is identified by a stable `adapter_id` (string, lowercase snake_case). Initial adapter set:

| `adapter_id` | Source | Deployments eligible |
|--------------|--------|----------------------|
| `stooq` | Stooq public CSV feeds | Duo Wealth, DataDuo |
| `yfinance` | yfinance package (public) | Duo Wealth, DataDuo |
| `user_csv` | User-supplied CSV (DataDuo Build-Your-Own-Warehouse) | DataDuo |
| `ibkr` | IBKR TWS API (personal license) | Duo Wealth only |
| `frd` | FirstRateData local files (personal license) | Duo Wealth only |

Adapter registration declares which deployments the adapter is eligible for. The adapter-registration layer enforces deployment eligibility — DataDuo deployments refuse to register `ibkr` or `frd` adapters at startup.

## Required Interface

Every adapter MUST implement:

```
ingest(instrument_id, start_date, end_date) -> Iterable[SourcePriceRecord]
reverse_adjust(record: SourcePriceRecord) -> UnadjustedPriceRecord
describe_capabilities() -> AdapterCapabilities
```

`ingest` returns source-native records with whatever adjustment state the source provides. `reverse_adjust` is MANDATORY and MUST produce an unadjusted raw record. `describe_capabilities` returns an `AdapterCapabilities` struct declaring supported instrument types, adjustment states the source provides, historical start date, update frequency, and known gaps.

## Reverse-Adjustment Requirement (Mandatory)

Every adapter MUST implement source-specific reverse-adjustment logic. Passthrough of source-provided adjusted prices is NOT a compliant implementation. The reason: the pipeline applies its own adjustment factors (derived from EDGAR 8-K Item 5.03 parsing) to produce research-tier prices. If an adapter skips reverse-adjustment, the pipeline would apply its adjustments on top of source-applied adjustments, double-adjusting the output.

Adapter-specific reverse-adjustment responsibilities:

- `stooq` — Stooq provides split-adjusted. Adapter reverses split adjustments using provider-published split factors plus EDGAR-verified split history.
- `yfinance` — yfinance provides total-return-adjusted by default and split-adjusted on request. Adapter normalizes to a known state, then reverses to unadjusted raw.
- `ibkr` — IBKR provides either ADJUSTED_LAST (split-adjusted) or TRADES (raw) per request type. Adapter requests TRADES where possible and reverses ADJUSTED_LAST where raw is not directly available.
- `frd` — FRD delivers split-adjusted by default. Adapter reverses using FRD-provided split metadata cross-checked against EDGAR.
- `user_csv` — user declares the adjustment state at CSV registration; adapter reverses according to declared state. If the user declares "unadjusted raw," no reversal is applied. If the user declares a state the adapter cannot reverse, registration fails.

Adapters that cannot reverse their source's adjustment state MUST fail registration with a clear error. Silent passthrough is a contract violation.

## Canonical Output Record

`ingest` returns records conforming to the canonical price record schema:

| Field | Type | Description |
|-------|------|-------------|
| `instrument_id` | string | Pipeline's internal instrument identifier (FIGI-derived) |
| `source_symbol` | string | Symbol as the source names it (may differ from canonical ticker) |
| `date` | date | Trading date |
| `open` | decimal | Opening price (source-native units) |
| `high` | decimal | High price |
| `low` | decimal | Low price |
| `close` | decimal | Closing price |
| `volume` | integer | Trading volume |
| `source_adjustment_state` | enum | `unadjusted` / `split_adjusted` / `total_return_adjusted` / `unknown` |
| `provenance` | provenance record | See `contracts/data-provenance-schema.md` |

After `reverse_adjust`, the record's `source_adjustment_state` MUST be `unadjusted` and a `reversal_applied` field in provenance records which reversal was performed.

## Error Handling

- **Source unavailable** — adapter raises `SourceUnavailableError`; pipeline retries per exponential backoff policy, then gates downstream publishing via M1e
- **Schema mismatch** — source returned data incompatible with canonical record; adapter raises `SchemaMismatchError`; record is quarantined, M1e alerts
- **Reversal failure** — adapter cannot reverse a record's adjustment state (e.g., unknown split factor); adapter raises `ReversalError`; record is quarantined with full source payload preserved in M1a raw store for later rerun
- **Deployment-ineligible adapter registration** — DataDuo deployment rejects `frd` or `ibkr` adapter registration at startup with `AdapterNotEligibleError`

Adapters MUST NOT silently substitute data, fall back to alternate sources, or proceed with unreversed adjustments under any error condition.

## Versioning

Adapter implementations are versioned independently via Git. A record's provenance includes the adapter's version string. Changes to reverse-adjustment logic that alter previously-ingested output are a MAJOR version bump and trigger re-ingestion of affected history through the new adapter version.

## Open Questions

- Handling of pre-IPO data gaps across adapters with different historical starts — per-instrument start-date floor in M1f lifecycle registry, adapters return empty for dates before listing
- User-CSV adapter edge cases — malformed CSV, non-monotonic dates, missing sessions vs. missing records — deferred to `user_csv` adapter implementation during DataDuo launch phase
- Exchange-cross-listing normalization (same instrument, different source symbols across adapters) — resolved via M1f + OpenFIGI, not at adapter layer

## Changelog

- 2026-04-19 — Initial contract created alongside ADR-003. Reverse-adjustment declared mandatory per ADR-003 unadjust-then-re-adjust principle.
