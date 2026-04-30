"""
Identity Spine Characterization v2
Fixes:
  1. Exact ticker matching in fja05680 parser
  2. Corrected OpenFIGI query with equity filters
  3. Test BRK.B / BF.B dot-notation variants
  4. Test CELG/LEH/AAPL with proper filters
"""

import requests, json, time
from pathlib import Path

OUT = Path("/tmp/identity_characterization")
OUT.mkdir(exist_ok=True)

# ── 1. fja05680 exact ticker matching fix ─────────────────────────────────────
print("=" * 70)
print("1. fja05680 sp500_ticker_start_end.csv — EXACT match")
print("=" * 70)

REPO = OUT / "sp500_repo"
csv_path = REPO / "sp500_ticker_start_end.csv"

if not csv_path.exists():
    print("Repo not found — clone it first")
else:
    import csv
    rows = []
    with open(csv_path) as f:
        reader = csv.DictReader(f)
        for row in reader:
            rows.append(row)

    print(f"Total rows: {len(rows)}")

    TEST = ["WB", "WBA", "CELG", "LEH", "LEHMQ", "BSC", "DELL",
            "GOOG", "GOOGL", "AAPL", "BRK/A", "BRK/B", "BRK.A", "BRK.B",
            "AAL", "ATVI", "TWTR", "RHT", "MYL", "RTN"]

    for ticker in TEST:
        # EXACT match on ticker column
        matches = [r for r in rows if r["ticker"].strip() == ticker]
        if matches:
            for m in matches:
                end = m["end_date"].strip() or "ACTIVE"
                print(f"  {ticker:8}: {m['start_date']} → {end}")
        else:
            print(f"  {ticker:8}: NOT IN UNIVERSE")

time.sleep(1)

# ── 2. Decorated historical file — WB disambiguation ─────────────────────────
print("\n" + "=" * 70)
print("2. Historical components file — WB decorated entries")
print("=" * 70)

hist_path = REPO / "S&P 500 Historical Components & Changes(01-17-2026).csv"
if hist_path.exists():
    import csv as csv_mod
    # Find all rows where WB appears (decorated or plain)
    wb_appearances = {}
    with open(hist_path) as f:
        reader = csv_mod.reader(f)
        header = next(reader)
        for row in reader:
            if len(row) < 2:
                continue
            date = row[0]
            tickers_str = row[1]
            # Find any token containing WB
            tokens = tickers_str.split(",")
            wb_tokens = [t.strip() for t in tokens if t.strip().startswith("WB")]
            for token in wb_tokens:
                wb_appearances.setdefault(token, []).append(date)

    print(f"WB-related tokens found: {list(wb_appearances.keys())}")
    for token, dates in wb_appearances.items():
        print(f"  {token}: first={min(dates)}, last={max(dates)}, count={len(dates)}")

time.sleep(1)

# ── 3. OpenFIGI corrected queries ─────────────────────────────────────────────
print("\n" + "=" * 70)
print("3. OpenFIGI — corrected equity filter queries")
print("=" * 70)

FIGI_URL = "https://api.openfigi.com/v3/mapping"

batch = [
    # AAPL — try exchCode US (NYSE) and UN (NASDAQ)
    {"idType": "TICKER", "idValue": "AAPL",  "exchCode": "US",  "marketSecDes": "Equity"},
    {"idType": "TICKER", "idValue": "AAPL",  "exchCode": "UN",  "marketSecDes": "Equity"},
    # BRK dot notation variants
    {"idType": "TICKER", "idValue": "BRK/B", "exchCode": "US",  "marketSecDes": "Equity"},
    {"idType": "TICKER", "idValue": "BRK.B", "exchCode": "US",  "marketSecDes": "Equity"},
    # BF dot notation
    {"idType": "TICKER", "idValue": "BF.B",  "exchCode": "US",  "marketSecDes": "Equity"},
    {"idType": "TICKER", "idValue": "BF/B",  "exchCode": "US",  "marketSecDes": "Equity"},
    # Delisted — no exchCode, just equity filter
    {"idType": "TICKER", "idValue": "CELG",  "marketSecDes": "Equity", "currency": "USD"},
    {"idType": "TICKER", "idValue": "LEH",   "marketSecDes": "Equity", "currency": "USD"},
    {"idType": "TICKER", "idValue": "BSC",   "marketSecDes": "Equity", "currency": "USD",
     "exchCode": "US"},  # Bear Stearns was NYSE
    {"idType": "TICKER", "idValue": "RHT",   "marketSecDes": "Equity", "currency": "USD"},
]

r = requests.post(
    FIGI_URL,
    json=batch,
    headers={"Content-Type": "application/json"},
    timeout=20
)

print(f"Status: {r.status_code}")
print(f"Rate limit remaining: {r.headers.get('ratelimit-remaining', '?')}")

if r.status_code == 200:
    results = r.json()
    for req, result in zip(batch, results):
        label = f"{req['idValue']:8} exchCode={req.get('exchCode','*'):4}"
        if "data" in result and result["data"]:
            # Filter to just US-relevant results
            us_results = [
                d for d in result["data"]
                if d.get("exchCode", "").startswith("U") or
                   d.get("exchCode", "") in ("US", "UN", "UA", "UQ", "UW")
            ]
            if us_results:
                for d in us_results[:2]:
                    print(f"  {label}: FIGI={d.get('figi')} | compFIGI={d.get('compositeFigi')} | "
                          f"name={d.get('name')} | type={d.get('securityType')} | "
                          f"exch={d.get('exchCode')}")
            else:
                # Show first result even if non-US
                d = result["data"][0]
                print(f"  {label}: NON-US result — name={d.get('name')} exch={d.get('exchCode')}")
        elif "warning" in result:
            print(f"  {label}: NO DATA — {result['warning']}")
        elif "error" in result:
            print(f"  {label}: ERROR — {result['error']}")
        else:
            print(f"  {label}: {result}")

    with open(OUT / "openfigi_v2.json", "w") as f:
        json.dump({"batch": batch, "results": results}, f, indent=2)

# ── 4. Summary of what each source can provide ────────────────────────────────
print("\n" + "=" * 70)
print("4. Source capability summary")
print("=" * 70)
print("""
  fja05680 sp500_ticker_start_end.csv:
    - Ticker + date_from + date_to for every S&P 500 membership period
    - Handles ticker reuse via multiple rows
    - Handles name-changes (LEH → LEHMQ)
    - 1,247 rows, back to 1996
    - PRIMARY source for universe membership and ticker interval seeding

  fja05680 Historical Components (decorated):
    - WB-200108 / WB-200812 encoding gives removal YYYYMM
    - Useful disambiguation for ticker reuse boundaries
    - SECONDARY evidence layer

  SEC company_tickers files:
    - Active filers only — no delisted coverage
    - CIK + current ticker + current name
    - GOOG and GOOGL share CIK 1652044 → proves issuer ≠ instrument
    - Use: CIK lookup for currently active instruments only

  OpenFIGI:
    - compositeFIGI is the right field to store (not exchange-specific FIGI)
    - 25 req/min unauthenticated
    - Active instruments only (no Bear Stearns, no Lehman)
    - Use: FIGI assignment for active/resolvable instruments; cache aggressively

  EDGAR individual submissions (not tested yet):
    - data.sec.gov/submissions/CIK{10-digit}.json
    - Available for ALL filers including delisted
    - Contains: name history, ticker history, former names, SIC, exchanges
    - Next source to characterize for lifecycle events
""")