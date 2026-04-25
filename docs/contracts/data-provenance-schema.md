# Contract: Data Provenance Schema

## Purpose

Defines the provenance metadata format attached to every value the pipeline produces. Provenance is what makes the pipeline auditable, the multi-source adapter pattern verifiable, and the three-warehouse validation protocol meaningful — every value in any warehouse can be traced back to its source, its adjustment state on arrival, and the transformations applied by the pipeline. Per ADR-003, provenance is mandatory on every pipeline value, not optional.

## Used By

- **M1a–c** (Raw / Canonical / Research stores) — persist provenance alongside values
- **M1g** (Price Source Adapter Layer) — emits provenance on adapter output
- **M1h** (Reconciliation Engine) — uses provenance to identify which source produced which value in discrepancy records
- **M1e** (Data Quality Validator) — uses provenance to attribute quality issues to specific sources, adapter versions, or transformation steps
- **M6** (Experiment Tracking) — run manifests reference provenance for the data snapshot consumed
- **DataDuo Enrichment API** — serves provenance as metadata on returned values so API consumers know the data's origin

## Provenance Record Schema

Every value in the canonical and research stores carries a provenance record. Fields:

| Field | Type | Description |
|-------|------|-------------|
| `provenance_id` | UUID | Unique per provenance record |
| `lineage_id` | UUID | Shared across all provenance records tracing to the same source ingestion event; enables grouping |
| `source_id` | string | `adapter_id` for prices (per `price-source-adapter.md`); source identifier for non-price domains (e.g., `sec_edgar`, `finra_short_interest`, `pandas_market_calendars`) |
| `source_version` | string | Version or release tag of the source data (e.g., an EDGAR filing accession number, an N-PORT report date, an API version) |
| `adapter_version` | string \| null | Version of the adapter implementation that produced this value (null for non-adapter sources) |
| `ingested_at` | timestamp | When the pipeline first captured this value |
| `source_adjustment_state` | enum \| null | `unadjusted` / `split_adjusted` / `total_return_adjusted` / `unknown` / null (for non-price domains) |
| `reversal_applied` | enum \| null | `none` / `split_reversal` / `total_return_reversal` / `multi_step` — records which reverse-adjustment was performed per the adapter's contract obligation |
| `transformations` | array[transformation record] | Ordered list of transformations the pipeline applied (see below) |
| `confidence_score` | decimal \| null | 0.0–1.0 confidence in this value (null if not scored); derived from reconciliation outcomes, source reputation, or explicit quality signals |
| `deployment` | enum | `duo_wealth` / `dataduo` — which deployment produced this provenance record |
| `superseded_by` | UUID \| null | If this provenance has been superseded (e.g., a re-ingestion corrected an earlier value), the provenance_id of the newer record |

## Transformation Record Schema

Each entry in the `transformations` array records one pipeline transformation:

| Field | Type | Description |
|-------|------|-------------|
| `transformation_id` | string | Identifier for the transformation logic (e.g., `split_adjust`, `dividend_adjust`, `total_return_compound`, `sector_classify`) |
| `transformation_version` | string | Version of the transformation implementation |
| `applied_at` | timestamp | When the transformation was applied |
| `inputs` | object | Reference to input values / factors used (e.g., `{split_factor_source: "edgar_8k_5.03", factor_record_id: "..."}`) |
| `notes` | text \| null | Optional free-text clarification for unusual cases |

Transformations are immutable once recorded. Re-applying a different version of a transformation produces a new provenance record (and the old record gets `superseded_by` set).

## Attachment Patterns

Provenance attaches to values at the granularity appropriate for each storage tier:

- **M1a Raw Store** — provenance per ingested record (one `provenance_id` per source record)
- **M1b Canonical Store** — provenance per canonical record; `lineage_id` links back to the raw record's provenance
- **M1c Research Store** — provenance per research-tier value; `lineage_id` links back to canonical; `transformations` array records the adjustments applied

A research-tier value's full lineage is reconstructable by following `lineage_id` back through canonical to raw, collecting the `transformations` applied at each tier.

## Serving via DataDuo API

DataDuo Enrichment API responses include per-value provenance (at minimum `source_id`, `source_version`, `adapter_version`, `transformations` list, `confidence_score`). Consumers of the API can audit which public-domain source produced any value they receive. This is one of the trust mechanisms that substantiates DataDuo's "public-domain enrichment, transparently sourced" positioning.

## Required Non-Null Fields

The following fields MUST be non-null on every provenance record produced by the pipeline:

- `provenance_id`
- `lineage_id`
- `source_id`
- `source_version`
- `ingested_at`
- `deployment`

`adapter_version`, `source_adjustment_state`, and `reversal_applied` MUST be non-null for records produced by adapters (per `price-source-adapter.md`); they MAY be null for non-adapter sources.

## Relationship to Reconciliation (M1h)

When M1h produces a discrepancy record (per `reconciliation-report-schema.md`), the `values` field of that record maps each source's identifier to the value that source produced. Each of those values has its own provenance record; the discrepancy record references them via `lineage_id`. This lets a reconciliation consumer drill into exactly which adapter version, transformation chain, or source vintage produced each compared value.

## Relationship to Experiment Tracking (M6)

Run manifests (per `run-manifest-format.md`, TBD) include a `data_snapshot` reference. The snapshot identifier points to a set of `lineage_id`s covering every value consumed by the run. This is how reproducibility is guaranteed — re-running from a manifest re-fetches values with those provenance lineages, not "equivalent" values from potentially different sources.

## Open Questions

- Provenance record size at scale — full provenance per research-tier value may balloon storage; compression / deduplication strategy TBD during M1 build
- Confidence score derivation — exact scoring function per domain, particularly for aggregate values like sector classifications that blend multiple sources
- Serving granularity for DataDuo — do all consumers get full provenance, or is provenance an opt-in API parameter
- Cross-deployment provenance portability — a Warehouse A built on DataDuo-cloud should produce provenance byte-identical to Warehouse A built on Duo-Wealth-local given identical inputs; test harness TBD

## Changelog

- 2026-04-19 — Initial contract created alongside ADR-003.
