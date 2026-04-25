# Contract: Reconciliation Report Schema

## Purpose

Defines the discrepancy record format produced by the Data Reconciliation Engine (M1h). Every cross-source comparison that surfaces a delta — whether in prices, corporate actions, universe membership, or any other capability domain — is recorded as a discrepancy record conforming to this schema. Downstream consumers (the Data Quality Validator M1e, the Comparative Truth Engine, audit trails) read this format.

## Used By

- **M1h** — Data Reconciliation Engine (produces discrepancy records)
- **M1e** — Data Quality Validator (consumes discrepancy records as one validation input)
- **M1** storage layer — persists records for audit and historical analysis
- **DataDuo Comparative Truth Engine** — aggregates discrepancy records into published accuracy deltas

## Discrepancy Record Schema

Every reconciliation comparison that produces a non-null delta emits one discrepancy record:

| Field | Type | Description |
|-------|------|-------------|
| `discrepancy_id` | UUID | Unique per record |
| `domain` | enum | `price` / `corporate_action` / `universe_membership` / `lifecycle` / `fundamentals` / `short_interest` / `holdings` / `insider_activity` / `macro` |
| `instrument_id` | string \| null | Canonical instrument identifier; null for domain-level discrepancies (e.g., universe membership discrepancies) |
| `as_of_date` | date | The date the compared values refer to |
| `detected_at` | timestamp | When the reconciliation ran |
| `sources_compared` | array[string] | `adapter_id`s (or source identifiers for non-price domains) whose values were compared |
| `values` | object | Map of source identifier → value produced by that source |
| `delta_type` | enum | `scalar_difference` / `categorical_mismatch` / `set_membership_delta` / `missing_from_source` |
| `delta_magnitude` | decimal \| null | Numeric magnitude for scalar deltas; null for categorical / set deltas |
| `severity` | enum | `informational` / `minor` / `material` / `blocking` |
| `severity_score` | decimal | Normalized 0.0–1.0 score per severity rules below |
| `resolution_state` | enum | `auto_resolved` / `pending_review` / `accepted_delta` / `escalated` / `superseded` |
| `resolution_rule_id` | string \| null | If auto-resolved, the rule identifier |
| `reviewer` | string \| null | If human-resolved, the reviewer identifier |
| `resolved_at` | timestamp \| null | When resolution was recorded |
| `notes` | text \| null | Free-text explanation |
| `provenance` | provenance record | See `contracts/data-provenance-schema.md` |

## Severity Scoring

Severity is domain-dependent. Each domain registers severity rules with M1h. Canonical rules for price domain:

| Severity | Rule |
|----------|------|
| `informational` | Scalar delta within ±0.01% of reference value |
| `minor` | ±0.01% to ±0.10% |
| `material` | ±0.10% to ±1.00% |
| `blocking` | Greater than ±1.00%, or categorical mismatch, or missing-from-source on a date the instrument was active per M1f lifecycle |

`severity_score` normalizes to 0.0–1.0 within the band (e.g., a `material` delta at 0.50% produces a score of ~0.5). Exact scoring functions per domain are defined in the M1h module spec when M1h is built.

Rules for corporate-action, universe-membership, and other domains are domain-specific and registered analogously. Any unrecognized domain-specific severity rule causes M1h to escalate the record as `pending_review`.

## Resolution States

- **`auto_resolved`** — matched a pipeline-registered auto-resolution rule (e.g., "stooq vs yfinance split-adjusted close within ±0.05% → accept stooq as canonical"). The `resolution_rule_id` names the rule.
- **`pending_review`** — requires human review; M1e gates affected downstream output until resolved.
- **`accepted_delta`** — human reviewer accepted the delta as a known source divergence; notes explain why. Does not gate downstream.
- **`escalated`** — reviewer escalated to architectural review; blocks downstream.
- **`superseded`** — a later reconciliation run resolved the same discrepancy with a newer record; this one is kept for audit trail.

## Persistence

Records are immutable once written except for the resolution fields (`resolution_state`, `resolution_rule_id`, `reviewer`, `resolved_at`, `notes`). Updates to resolution fields write a new version of the record; the prior version remains with `resolution_state = superseded`. This preserves full audit history — a later reviewer can always see the sequence of resolution decisions for a given discrepancy.

## Relationship to Data Quality Validator (M1e)

M1h produces discrepancy records; it does not gate downstream publishing on its own. M1e consumes discrepancy records and applies gating rules: any record with `resolution_state = pending_review` or `escalated` and `severity = material` or `blocking` blocks downstream publishing for the affected instrument/domain/date until resolved. This separation keeps M1h purely diagnostic and M1e purely enforcement.

## Relationship to Three-Warehouse Validation Protocol

M1h reconciles within a single warehouse's sources at ingestion time. The three-warehouse validation protocol (see `contracts/validation-protocol.md`) compares entire warehouses against each other at the strategy-outcome level. Discrepancy records from M1h feed per-warehouse data quality; warehouse-level comparisons operate at a coarser granularity and are not recorded in this schema.

## Aggregation for DataDuo Comparative Truth Engine

Discrepancy records across the capability domains aggregate into per-domain accuracy deltas (e.g., "99.94% of Stooq-vs-yfinance close prices on S&P 500 constituents 2005–present match within ±0.01%"). Aggregation logic lives in the Comparative Truth Engine subsystem, not in this contract. This contract guarantees that the raw records necessary for aggregation are present and uniform.

## Open Questions

- Retention period for superseded resolution records — indefinite vs. time-bounded
- Whether discrepancy records are themselves surfaced via DataDuo API or kept internal
- Auto-resolution rule authoring interface — declarative config vs. code
- Cross-domain compound discrepancies (e.g., price discrepancy on an instrument whose lifecycle is simultaneously in dispute) — modeled as linked records or as a single compound record

## Changelog

- 2026-04-19 — Initial contract created alongside ADR-003.
