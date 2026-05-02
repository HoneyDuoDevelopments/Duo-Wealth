-- =============================================================================
-- 001_identity_spine.up.sql
-- Stage 1A-A1: Identity Spine
-- =============================================================================
-- Purpose:
--   Shared issuer/instrument identity foundation used by all three warehouses
--   (A, B, C) and the DataDuo enrichment layer. No price tables. No warehouse-
--   specific logic. Every price row in every warehouse references instrument_id
--   from this schema.
--
-- Design decisions (see ADR-003 and identity-source-characterization doc):
--   - CIK identifies issuer/filer, not tradable security (GOOG/GOOGL share CIK)
--   - instrument_id is the stable internal PK; tickers are attributes, not keys
--   - Ticker queries MUST include as_of_date; ticker-only lookups are forbidden
--   - Evidence conflicts are logged, not silently rejected by DB constraints
--   - No overlap exclusion constraints: load evidence, log conflicts, resolve
--     deliberately after inspection
--
-- Sources ingested in later stages:
--   Stage 1: SEC company_tickers.json (active issuer bridge)
--   Stage 1: EDGAR individual submissions (delisted issuer resolution)
--   Stage 1: OpenFIGI mapping API (FIGI assignment)
--   Stage 2: fja05680 sp500_ticker_start_end.csv (universe + provisional instruments)
--   Stage 2: fja05680 S&P 500 Historical Components & Changes.csv (membership events)
-- =============================================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- =============================================================================
-- ENUMS
-- =============================================================================

CREATE TYPE source_confidence_enum AS ENUM (
    'confirmed',    -- cross-validated from multiple independent sources
    'probable',     -- single strong source, high confidence
    'inferred',     -- derived from indirect evidence
    'provisional',  -- seeded from one source, not yet validated
    'conflict',     -- multiple sources disagree, needs resolution
    'unresolved'    -- no reliable source found
);

CREATE TYPE issuer_status_enum AS ENUM (
    'active',
    'inactive',
    'unknown'
);

CREATE TYPE instrument_lifecycle_status_enum AS ENUM (
    'active',
    'delisted',
    'acquired',
    'merged',
    'bankrupt',
    'relisted',
    'unknown'
);

CREATE TYPE instrument_type_enum AS ENUM (
    'common_stock',
    'adr',
    'etf',
    'preferred',
    'warrant',
    'unit',
    'index',        -- for index-linked membership tracking (SPX, etc.)
    'unknown'
);

CREATE TYPE lifecycle_event_type_enum AS ENUM (
    'acquired',             -- target acquired by another company
    'merged',               -- two companies combined into new entity
    'bankrupt',             -- filed Chapter 7/11, trading ceased
    'ticker_change',        -- same instrument, new ticker symbol
    'name_change',          -- same instrument, legal name changed
    'delisted_voluntary',   -- company chose to delist
    'delisted_forced',      -- exchange-initiated delisting
    'spinoff',              -- new instrument created from parent
    'relisted'              -- previously delisted instrument returned to trading
);

CREATE TYPE resolution_status_enum AS ENUM (
    'resolved',     -- unique instrument_id found
    'unresolved',   -- no matching instrument found
    'ambiguous',    -- multiple candidates, cannot determine unique
    'conflict',     -- sources disagree on identity
    'rejected'      -- lookup rejected (e.g. missing as_of_date)
);

-- =============================================================================
-- TRIGGER FUNCTION: updated_at
-- Applied to tables with an updated_at column.
-- =============================================================================

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- ISSUER MASTER
-- =============================================================================
-- CIK belongs here. One issuer (CIK) may have multiple instruments
-- (share classes, ADRs, etc.). This is the legal entity layer.
--
-- Examples:
--   Alphabet Inc. (CIK 1652044) → instruments: GOOGL (Class A), GOOG (Class C)
--   Berkshire Hathaway          → instruments: BRK.A, BRK.B

CREATE TABLE issuer_master (
    issuer_id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    primary_cik         TEXT NULL,
    legal_name          TEXT NULL,
    display_name        TEXT NULL,
    country             TEXT NULL,
    issuer_status       issuer_status_enum NOT NULL DEFAULT 'unknown',
    source_confidence   source_confidence_enum NOT NULL DEFAULT 'provisional',
    notes               TEXT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- CIK uniqueness: one primary CIK per issuer record. Historical CIK changes
-- go in issuer_cik_history.
CREATE UNIQUE INDEX ux_issuer_master_primary_cik
ON issuer_master (primary_cik)
WHERE primary_cik IS NOT NULL;

CREATE TRIGGER trg_issuer_master_updated_at
    BEFORE UPDATE ON issuer_master
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =============================================================================
-- INSTRUMENT MASTER
-- =============================================================================
-- Tradable security / share class. Multiple instruments may share one issuer.
-- issuer_id is nullable: an instrument can exist with ticker evidence alone
-- before CIK/issuer is resolved (e.g. LEHMQ, historical delistings).

CREATE TABLE instrument_master (
    instrument_id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    issuer_id                UUID NULL REFERENCES issuer_master(issuer_id),
    instrument_type          instrument_type_enum NOT NULL DEFAULT 'unknown',
    share_class              TEXT NULL,
    primary_listing_exchange TEXT NULL,
    lifecycle_status         instrument_lifecycle_status_enum NOT NULL DEFAULT 'unknown',
    born_date                DATE NULL,
    death_date               DATE NULL,
    death_reason             TEXT NULL,
    source_confidence        source_confidence_enum NOT NULL DEFAULT 'provisional',
    notes                    TEXT NULL,
    created_at               TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at               TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT ck_instrument_lifecycle_dates
        CHECK (death_date IS NULL OR born_date IS NULL OR death_date >= born_date)
);

CREATE INDEX ix_instrument_master_issuer_id
ON instrument_master (issuer_id);

CREATE INDEX ix_instrument_master_lifecycle_status
ON instrument_master (lifecycle_status);

CREATE TRIGGER trg_instrument_master_updated_at
    BEFORE UPDATE ON instrument_master
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =============================================================================
-- TICKER IDENTIFIER HISTORY
-- =============================================================================
-- Date-bounded ticker → instrument mapping. This table is load-bearing for
-- all ticker reuse resolution. Never query by ticker alone.
--
-- Three ticker forms stored per row:
--   raw_ticker:        exactly what the source gave us (e.g. "BRK.B" from fja05680)
--   normalized_ticker: internal canonical form for comparison (e.g. "BRKB")
--   source_ticker:     source/adapter-specific query form (e.g. "BRK/B" for OpenFIGI)
--
-- No overlap exclusion constraints: source intervals may overlap during ingestion.
-- Conflicts are logged in identifier_resolution_audit and resolved deliberately.

CREATE TABLE ticker_identifier_history (
    ticker_id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    instrument_id      UUID NOT NULL REFERENCES instrument_master(instrument_id),
    raw_ticker         TEXT NOT NULL,
    normalized_ticker  TEXT NOT NULL,
    source_ticker      TEXT NOT NULL,
    exchange           TEXT NULL,
    date_from          DATE NOT NULL,
    date_to            DATE NULL,           -- NULL = currently active
    source_name        TEXT NOT NULL,
    source_confidence  source_confidence_enum NOT NULL DEFAULT 'provisional',
    is_primary         BOOLEAN NOT NULL DEFAULT TRUE,
    notes              TEXT NULL,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT ck_ticker_identifier_dates
        CHECK (date_to IS NULL OR date_to >= date_from)
);

-- Primary lookup index: normalized ticker + date range
CREATE INDEX ix_ticker_identifier_lookup
ON ticker_identifier_history (normalized_ticker, date_from, date_to);

CREATE INDEX ix_ticker_identifier_instrument
ON ticker_identifier_history (instrument_id);

CREATE INDEX ix_ticker_identifier_source
ON ticker_identifier_history (source_name);

-- Deduplication: same instrument + ticker + exchange + interval + source is unique
CREATE UNIQUE INDEX ux_ticker_identifier_source_interval
ON ticker_identifier_history (
    instrument_id,
    normalized_ticker,
    COALESCE(exchange, ''),
    date_from,
    COALESCE(date_to, DATE '9999-12-31'),
    source_name
);

-- =============================================================================
-- ISSUER CIK HISTORY
-- =============================================================================
-- CIK → issuer mapping, date-bounded to handle rare CIK changes.
-- Most issuers will have one row. Supports SEC EDGAR lookups.

CREATE TABLE issuer_cik_history (
    cik_id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    issuer_id          UUID NOT NULL REFERENCES issuer_master(issuer_id),
    cik                TEXT NOT NULL,
    date_from          DATE NULL,
    date_to            DATE NULL,
    source_name        TEXT NOT NULL,
    source_confidence  source_confidence_enum NOT NULL DEFAULT 'provisional',
    raw_payload        JSONB NULL,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT ck_issuer_cik_dates
        CHECK (date_to IS NULL OR date_from IS NULL OR date_to >= date_from)
);

CREATE INDEX ix_issuer_cik_lookup
ON issuer_cik_history (cik);

CREATE INDEX ix_issuer_cik_issuer
ON issuer_cik_history (issuer_id);

CREATE UNIQUE INDEX ux_issuer_cik_source
ON issuer_cik_history (
    issuer_id,
    cik,
    COALESCE(date_from, DATE '0001-01-01'),
    COALESCE(date_to, DATE '9999-12-31'),
    source_name
);

-- =============================================================================
-- FIGI IDENTIFIER HISTORY
-- =============================================================================
-- OpenFIGI mapping — supplemental identifier layer.
-- composite_figi is the preferred match key for US-listed common equity.
-- All three FIGI levels stored: figi (exchange-specific), composite_figi
-- (instrument-level), share_class_figi (share class level).
-- raw_response preserved for audit.
--
-- Key empirical findings:
--   - CELG resolved (BBG000BFCMR2) despite being delisted 2019 — partial coverage
--   - LEH, BSC, RHT did not resolve — do not assume zero coverage, do not assume full
--   - OpenFIGI uses slash notation for share classes: BRK/B, BF/B (not dot notation)

CREATE TABLE figi_identifier_history (
    figi_id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    instrument_id      UUID NOT NULL REFERENCES instrument_master(instrument_id),
    figi               TEXT NULL,           -- exchange-specific FIGI
    composite_figi     TEXT NULL,           -- instrument-level, preferred for matching
    share_class_figi   TEXT NULL,           -- share class level
    exch_code          TEXT NULL,
    mic_code           TEXT NULL,
    market_sector      TEXT NULL,
    security_type      TEXT NULL,
    security_type2     TEXT NULL,
    name               TEXT NULL,
    ticker             TEXT NULL,
    date_from          DATE NULL,
    date_to            DATE NULL,
    source_name        TEXT NOT NULL DEFAULT 'openfigi',
    source_confidence  source_confidence_enum NOT NULL DEFAULT 'provisional',
    raw_response       JSONB NULL,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT ck_figi_dates
        CHECK (date_to IS NULL OR date_from IS NULL OR date_to >= date_from),

    CONSTRAINT ck_figi_any_identifier
        CHECK (
            figi IS NOT NULL
            OR composite_figi IS NOT NULL
            OR share_class_figi IS NOT NULL
        )
);

CREATE INDEX ix_figi_identifier_instrument
ON figi_identifier_history (instrument_id);

CREATE INDEX ix_figi_identifier_composite
ON figi_identifier_history (composite_figi)
WHERE composite_figi IS NOT NULL;

CREATE INDEX ix_figi_identifier_share_class
ON figi_identifier_history (share_class_figi)
WHERE share_class_figi IS NOT NULL;

CREATE INDEX ix_figi_identifier_figi
ON figi_identifier_history (figi)
WHERE figi IS NOT NULL;

-- =============================================================================
-- UNIVERSE MEMBERSHIP
-- =============================================================================
-- Point-in-time membership records. Backtests query this by date to get the
-- correct universe snapshot without future leakage.
--
-- universe_code values: 'SP500', 'SP400'
-- date_to NULL = currently active member
--
-- Query pattern (enforced at application layer, not DB):
--   SELECT instrument_id FROM universe_membership
--   WHERE universe_code = 'SP500'
--     AND date_from <= :as_of_date
--     AND (date_to IS NULL OR date_to > :as_of_date)

CREATE TABLE universe_membership (
    membership_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    instrument_id      UUID NOT NULL REFERENCES instrument_master(instrument_id),
    universe_code      TEXT NOT NULL,
    date_from          DATE NOT NULL,
    date_to            DATE NULL,           -- NULL = currently active
    source_name        TEXT NOT NULL,
    source_confidence  source_confidence_enum NOT NULL DEFAULT 'provisional',
    notes              TEXT NULL,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT ck_universe_membership_dates
        CHECK (date_to IS NULL OR date_to >= date_from)
);

-- Primary point-in-time query index
CREATE INDEX ix_universe_membership_asof
ON universe_membership (universe_code, date_from, date_to);

CREATE INDEX ix_universe_membership_instrument
ON universe_membership (instrument_id);

CREATE UNIQUE INDEX ux_universe_membership_source_interval
ON universe_membership (
    instrument_id,
    universe_code,
    date_from,
    COALESCE(date_to, DATE '9999-12-31'),
    source_name
);

-- =============================================================================
-- LIFECYCLE EVENTS
-- =============================================================================
-- Records why an instrument's identity changed or terminated.
-- Sourced primarily from EDGAR 8-K filings (later stages).
-- source_accession: EDGAR accession number when applicable.

CREATE TABLE lifecycle_event (
    event_id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    instrument_id         UUID NOT NULL REFERENCES instrument_master(instrument_id),
    event_type            lifecycle_event_type_enum NOT NULL,
    event_date            DATE NOT NULL,
    event_effective_date  DATE NULL,
    source_name           TEXT NOT NULL,
    source_url            TEXT NULL,
    source_accession      TEXT NULL,        -- EDGAR accession number e.g. 0001234567-08-000001
    event_confidence      source_confidence_enum NOT NULL DEFAULT 'provisional',
    description           TEXT NULL,
    raw_payload           JSONB NULL,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX ix_lifecycle_event_instrument
ON lifecycle_event (instrument_id);

CREATE INDEX ix_lifecycle_event_type_date
ON lifecycle_event (event_type, event_date);

-- =============================================================================
-- IDENTIFIER RESOLUTION AUDIT
-- =============================================================================
-- Every resolver attempt is logged here — both successes and failures.
-- Critical for debugging identity failures during backtest validation (Phase B).
-- input_source: 'stooq_adapter', 'yfinance_adapter', 'wiki_adapter', etc.

CREATE TABLE identifier_resolution_audit (
    audit_id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    input_identifier        TEXT NOT NULL,
    input_date              DATE NULL,
    input_source            TEXT NOT NULL,
    resolved_instrument_id  UUID NULL REFERENCES instrument_master(instrument_id),
    resolution_status       resolution_status_enum NOT NULL,
    resolution_reason       TEXT NULL,
    candidate_payload       JSONB NULL,     -- candidates when ambiguous/conflict
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX ix_identifier_resolution_input
ON identifier_resolution_audit (input_identifier, input_date);

CREATE INDEX ix_identifier_resolution_status
ON identifier_resolution_audit (resolution_status);

CREATE INDEX ix_identifier_resolution_resolved
ON identifier_resolution_audit (resolved_instrument_id)
WHERE resolved_instrument_id IS NOT NULL;

COMMIT;