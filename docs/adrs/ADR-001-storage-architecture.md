# ADR-001: Storage Architecture — PostgreSQL + Parquet + DuckDB

## Status
Accepted

## Date
2026-04-09

## Context
The Duo Wealth data layer (M1) needs to support two fundamentally different workload patterns:

1. **Transactional writes** — ingesting market data, recording corporate actions, maintaining the security master, tracking pipeline state. These need ACID guarantees, foreign keys, and constraint checking.

2. **Analytical reads** — loading 20+ years of adjusted daily OHLCV for hundreds of instruments into backtest engines, running cross-sectional factor analysis, generating research datasets. These need columnar compression, vectorized execution, and fast bulk reads.

No single storage system handles both well. The blueprint specifies MySQL (existing Honey Duo infrastructure), but MySQL is not currently deployed on the Ubuntu system and PostgreSQL offers significant advantages for this workload.

## Decision
Three-part storage architecture:

**PostgreSQL 16** — operational database for all transactional workloads:
- Security master (CIK, FIGI, ticker history)
- Raw price store (immutable vendor payloads)
- Corporate actions (splits, dividends, mergers, delistings)
- Universe registry (index membership, eligibility)
- Data quality records (check results, incidents)
- Pipeline metadata (job logs, provenance, snapshots)
- Experiment tracking (run manifests)

**Parquet files** — columnar analytical warehouse for research reads:
- Adjusted daily OHLCV series
- Total-return-adjusted series
- Point-in-time fundamentals snapshots
- Derived factor tables
- Universe membership snapshots
- DataDuo export format (flat file tier)

**DuckDB** — embedded analytical query engine over Parquet:
- Backtest engine data loading
- Ad-hoc research queries (SQL over Parquet)
- Cross-sectional analysis
- DataDuo API query serving

Data flows one direction: Sources → PostgreSQL → Parquet → DuckDB reads.

Two PostgreSQL instances (Docker containers, separate ports, separate volumes):
- **Test** (port 5433) — development and validation
- **Prod** (port 5434) — production data, started only when ready

## Alternatives Considered

**MySQL only** — blueprint's original specification. MySQL lacks native JSON path queries (important for EDGAR XBRL), has weaker window functions, and doesn't support table partitioning as cleanly. No existing MySQL instance on Ubuntu to reuse.

**PostgreSQL only** — would work at current scale but analytical queries against relational tables are 10-100x slower than DuckDB on Parquet for the backtest workload pattern. Also makes DataDuo flat file export less natural.

**SQLite + Parquet** — simpler but SQLite's single-writer limitation would block concurrent ingestion pipelines. No network access for future multi-client scenarios.

**TimescaleDB** — PostgreSQL extension for time-series. Considered overkill for daily-resolution data. Adds operational complexity. If minute-bar data becomes relevant, revisit.

## Consequences

**Enables:**
- Clean separation of write-heavy and read-heavy workloads
- Parquet files are trivially portable (DataDuo flat file tier)
- DuckDB queries are fast without database server overhead
- Test/prod isolation via separate containers

**Constrains:**
- Data must flow through an explicit build/export pipeline from PostgreSQL to Parquet
- Two systems to understand instead of one
- Parquet files must be rebuilt when upstream data changes (corporate actions, corrections)

**Operational:**
- PostgreSQL runs as Docker container on Ubuntu (192.168.0.245)
- Parquet files stored on local NVMe filesystem
- DuckDB is embedded (no server) — imported as Python library
- Backups: PostgreSQL via pg_dump to OneDrive, Parquet files are reproducible from PostgreSQL

## Revisit If
- Data volume exceeds NVMe capacity (500GB) — consider external storage
- Minute-bar intraday data becomes a priority — evaluate TimescaleDB
- Multi-user concurrent access needed — evaluate dedicated DuckDB server mode
- PostgreSQL becomes a bottleneck on daily ingestion — unlikely at daily EOD resolution
