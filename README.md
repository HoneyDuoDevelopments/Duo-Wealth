# Duo Wealth — Strategy Incubator

A modular, strategy-agnostic algorithmic trading research and deployment platform.

**Owner:** Sam
**System:** Ubuntu RTX 3090 (192.168.0.245)
**Infrastructure:** [honey-duo-infrastructure](https://github.com/HoneyDuoDevelopments/honey-duo-infrastructure)

## What This Is

The operating system that produces, evaluates, manages, and retires trading bots. Not a trading bot itself — a workbench for building, testing, validating, and deploying them.

See [docs/blueprint.md](docs/blueprint.md) for the full system architecture.

## Current Phase

**Phase 1A:** Data Foundation (IN PROGRESS)
- [ ] PostgreSQL test + prod instances running
- [ ] Security master table (EDGAR + OpenFIGI)
- [ ] Split events table (EDGAR 8-K parser)
- [ ] Split factor engine with unit tests
- [ ] IBKR TRADES ingest → raw store
- [ ] Corporate actions full table
- [ ] Price research layer (canonical store)

See [docs/roadmap.md](docs/roadmap.md) for the full build sequence.

## Quick Start

```bash
# Clone
cd /home/honey-duo
git clone git@github.com:HoneyDuoDevelopments/Duo-Wealth.git
cd Duo-Wealth

# Copy environment template and fill in credentials
cp .env.example .env
# Edit .env with values from Vaultwarden → Infrastructure → "Duo Wealth DB"

# Start database (test instance)
docker compose -f infrastructure/docker-compose.yml up -d duo-wealth-db-test

# Verify
docker compose -f infrastructure/docker-compose.yml ps
```

## Repository Structure

```
Duo-Wealth/
├── docs/                    # Architecture, specs, decisions
│   ├── blueprint.md         # System end-state definition
│   ├── roadmap.md           # Build sequence and priorities
│   ├── adrs/                # Architecture Decision Records
│   ├── contracts/           # Shared interface specs (built as needed)
│   ├── modules/             # Module specs (built as needed)
│   ├── research/            # Research findings
│   └── session-guides/      # Context bundles for AI sessions
├── src/                     # Source code (grows with modules)
│   ├── data/                # M1 — Data Layer
│   └── shared/              # Config, types, utilities
├── tests/                   # Test suite
├── infrastructure/          # Docker Compose, deployment configs
├── .env.example             # Environment template (safe to commit)
└── .gitignore
```

## Technology Stack

| Component | Technology | Notes |
|-----------|-----------|-------|
| Language | Python 3.12+ | Primary for everything |
| Operational DB | PostgreSQL 16 | Security master, pipeline state, metadata |
| Research Warehouse | Parquet files | Analytical reads, backtest data |
| Query Engine | DuckDB | SQL over Parquet, ad-hoc research |
| Data Sources | IBKR, EDGAR, FRD, FRED, OpenFIGI | See ADR-001 |
| Containerization | Docker Compose | Database instances only — app is not containerized |

## Integration

- **Monitoring:** Uptime Kuma health check on PostgreSQL
- **Secrets:** Vaultwarden → Infrastructure → "Duo Wealth DB"
- **Backups:** Automated to OneDrive (after validation)
- **Alerts:** Discord #honey-duo-alerts (via existing Alertmanager)
- **Infrastructure docs:** `honey-duo-infrastructure/ubuntu/duo-wealth/`

## Documentation

- [Blueprint](docs/blueprint.md) — Full system architecture
- [Roadmap](docs/roadmap.md) — Build sequence and current phase
- [ADR-001: Storage Architecture](docs/adrs/ADR-001-storage-architecture.md)
- [ADR-002: Data Provider Stack](docs/adrs/ADR-002-data-provider-stack.md)

## License

Private — Personal Use Only
