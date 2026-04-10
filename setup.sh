#!/bin/bash
# ============================================================
# Duo Wealth — Initial Setup Script
# Run on Ubuntu RTX 3090 (192.168.0.245)
#
# What this does:
#   1. Initializes the Duo-Wealth Git repo
#   2. Creates .env from template (you fill in passwords)
#   3. Starts PostgreSQL test instance
#   4. Installs Python dependencies
#   5. Runs smoke tests
#   6. Makes first commit and pushes to GitHub
#
# Prerequisites:
#   - Files from duo-wealth/ directory already in ~/Duo-Wealth/
#   - Docker and Docker Compose installed
#   - Python 3.12+ installed
#   - SSH key configured for GitHub
# ============================================================

set -e  # Exit on any error

REPO_DIR="$HOME/Duo-Wealth"
INFRA_DIR="$HOME/honey-duo-infrastructure"
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "============================================"
echo "  Duo Wealth — Initial Setup"
echo "============================================"
echo ""

# ---- Step 1: Check prerequisites ----
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker not found. Install Docker first.${NC}"
    exit 1
fi

if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Python3 not found.${NC}"
    exit 1
fi

PYTHON_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
echo "  Python: $PYTHON_VERSION"
echo "  Docker: $(docker --version | cut -d' ' -f3)"
echo -e "${GREEN}  Prerequisites OK${NC}"
echo ""

# ---- Step 2: Initialize Git repo ----
echo -e "${YELLOW}Initializing Git repository...${NC}"
cd "$REPO_DIR"

if [ ! -d .git ]; then
    git init
    git remote add origin git@github.com:HoneyDuoDevelopments/Duo-Wealth.git
    echo -e "${GREEN}  Git initialized${NC}"
else
    echo "  Git already initialized — skipping"
fi
echo ""

# ---- Step 3: Create .env ----
echo -e "${YELLOW}Setting up environment...${NC}"

if [ ! -f .env ]; then
    cp .env.example .env
    echo -e "${YELLOW}  Created .env from template${NC}"
    echo ""
    echo "  ┌─────────────────────────────────────────────────────┐"
    echo "  │  ACTION REQUIRED: Edit .env with real passwords     │"
    echo "  │                                                     │"
    echo "  │  Generate two strong passwords and store them in    │"
    echo "  │  Vaultwarden → Infrastructure:                      │"
    echo "  │    • 'Duo Wealth DB Test'                           │"
    echo "  │    • 'Duo Wealth DB Prod'                           │"
    echo "  │                                                     │"
    echo "  │  Then edit: nano ~/Duo-Wealth/.env                  │"
    echo "  └─────────────────────────────────────────────────────┘"
    echo ""
    read -p "  Press Enter after you've edited .env (or Ctrl+C to exit and do it later)..."
else
    echo "  .env already exists — skipping"
fi
echo ""

# ---- Step 4: Start PostgreSQL test instance ----
echo -e "${YELLOW}Starting PostgreSQL test instance...${NC}"
cd "$REPO_DIR/infrastructure"
docker compose up -d duo-wealth-db-test

# Wait for healthy
echo "  Waiting for PostgreSQL to be ready..."
for i in {1..30}; do
    if docker compose exec duo-wealth-db-test pg_isready -U "$(grep POSTGRES_TEST_USER "$REPO_DIR/.env" | cut -d= -f2)" &> /dev/null; then
        echo -e "${GREEN}  PostgreSQL test instance is ready${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}  PostgreSQL failed to start after 30 seconds${NC}"
        echo "  Check: docker compose logs duo-wealth-db-test"
        exit 1
    fi
    sleep 1
done
echo ""

# ---- Step 5: Python virtual environment ----
echo -e "${YELLOW}Setting up Python environment...${NC}"
cd "$REPO_DIR"

if [ ! -d .venv ]; then
    python3 -m venv .venv
    echo "  Created virtual environment"
fi

source .venv/bin/activate
pip install --quiet -r requirements.txt
echo -e "${GREEN}  Python dependencies installed${NC}"
echo ""

# ---- Step 6: Run smoke tests ----
echo -e "${YELLOW}Running smoke tests...${NC}"
python tests/test_db_connection.py
echo ""

# ---- Step 7: First commit ----
echo -e "${YELLOW}Making first commit...${NC}"
cd "$REPO_DIR"
git add .
git commit -m "Initial scaffolding: PostgreSQL, project structure, ADRs

- PostgreSQL 16 Docker Compose (test on 5433, prod on 5434)
- ADR-001: Storage architecture (PostgreSQL + Parquet + DuckDB)
- ADR-002: Data provider stack (FRD + IBKR + EDGAR)
- Project structure following documentation architecture plan
- Smoke tests for database connectivity
- .env template for credentials (actual .env gitignored)"

git branch -M main
git push -u origin main
echo -e "${GREEN}  Pushed to GitHub${NC}"
echo ""

# ---- Step 8: Infrastructure repo updates ----
echo -e "${YELLOW}Updating infrastructure repo...${NC}"

if [ -d "$INFRA_DIR" ]; then
    cd "$INFRA_DIR"
    git pull origin main

    # Create duo-wealth integration directory
    mkdir -p ubuntu/duo-wealth

    if [ -f "$REPO_DIR/../duo-wealth-package/infra-updates/ubuntu/duo-wealth/README.md" ]; then
        cp "$REPO_DIR/../duo-wealth-package/infra-updates/ubuntu/duo-wealth/README.md" ubuntu/duo-wealth/README.md
        echo "  Copied integration README"
    else
        echo -e "${YELLOW}  Infrastructure README not found in package — copy manually${NC}"
        echo "  Source: infra-updates/ubuntu/duo-wealth/README.md"
        echo "  Dest:   $INFRA_DIR/ubuntu/duo-wealth/README.md"
    fi

    echo ""
    echo "  ┌─────────────────────────────────────────────────────┐"
    echo "  │  MANUAL STEPS for infrastructure repo:              │"
    echo "  │                                                     │"
    echo "  │  1. Update github/REPOSITORIES.md                   │"
    echo "  │     (add Duo-Wealth as repo #5)                     │"
    echo "  │                                                     │"
    echo "  │  2. Update ubuntu/README.md port table              │"
    echo "  │     (add ports 5433, 5434)                          │"
    echo "  │                                                     │"
    echo "  │  3. Add Uptime Kuma TCP monitor                     │"
    echo "  │     Target: 192.168.0.245:5433                      │"
    echo "  │     Interval: 60s                                   │"
    echo "  │                                                     │"
    echo "  │  4. Commit and push infrastructure changes          │"
    echo "  │     cd ~/honey-duo-infrastructure                   │"
    echo "  │     git add .                                       │"
    echo "  │     git commit -m "Add Duo Wealth integration"      │"
    echo "  │     git push origin main                            │"
    echo "  └─────────────────────────────────────────────────────┘"
else
    echo -e "${YELLOW}  Infrastructure repo not found at $INFRA_DIR${NC}"
    echo "  Update it manually after setup."
fi

echo ""
echo "============================================"
echo -e "${GREEN}  Setup complete!${NC}"
echo "============================================"
echo ""
echo "  Duo Wealth repo:  ~/Duo-Wealth"
echo "  PostgreSQL test:  localhost:5433"
echo "  Activate venv:    cd ~/Duo-Wealth && source .venv/bin/activate"
echo "  Run tests:        pytest tests/ -v"
echo ""
echo "  Next session: Security master schema + EDGAR ingestion"
echo ""
