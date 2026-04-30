-- =============================================================================
-- 001_identity_spine.down.sql
-- Stage 1A-A1: Identity Spine — Rollback
-- =============================================================================
-- Drops all objects created by 001_identity_spine.up.sql in reverse dependency
-- order. Fully reversible.
-- =============================================================================

BEGIN;

-- Tables (reverse FK dependency order)
DROP TABLE IF EXISTS identifier_resolution_audit;
DROP TABLE IF EXISTS lifecycle_event;
DROP TABLE IF EXISTS universe_membership;
DROP TABLE IF EXISTS figi_identifier_history;
DROP TABLE IF EXISTS issuer_cik_history;
DROP TABLE IF EXISTS ticker_identifier_history;
DROP TABLE IF EXISTS instrument_master;
DROP TABLE IF EXISTS issuer_master;

-- Trigger function
DROP FUNCTION IF EXISTS set_updated_at();

-- Enums
DROP TYPE IF EXISTS resolution_status_enum;
DROP TYPE IF EXISTS lifecycle_event_type_enum;
DROP TYPE IF EXISTS instrument_type_enum;
DROP TYPE IF EXISTS instrument_lifecycle_status_enum;
DROP TYPE IF EXISTS issuer_status_enum;
DROP TYPE IF EXISTS source_confidence_enum;

COMMIT;