"""
Wayback Machine CDX scan for delisted ticker coverage.
Tests 10 tickers across different eras and delisting types.
For each ticker, finds all archived snapshots of the Yahoo Finance
history page with date-range parameters (the ones that contain
embedded JSON price data).
"""
import requests, re, json, time
from urllib.parse import quote

TICKERS = {
    # Pre-2016 (low/zero coverage expected)
    "LEH":  ("lehman-brothers",      2008, "bankruptcy"),
    "BSC":  ("bear-stearns",         2008, "acquisition"),
    "WB":   ("wachovia",             2008, "acquisition"),
    "SHLD": ("sears-holdings",       2018, "bankruptcy"),  # slow death from 2012
    # Post-2016 (better coverage expected)
    "CELG": ("celgene",              2019, "acquisition"),
    "RHT":  ("red-hat",             2019, "acquisition"),
    "TWTR": ("twitter",             2022, "acquisition"),
    "ATVI": ("activision-blizzard", 2023, "acquisition"),
    "MYL":  ("mylan",               2020, "merger"),
    "RTN":  ("raytheon",            2020, "merger"),       # merged with UTC -> RTX
}

CDX_BASE = "https://web.archive.org/cdx/search/cdx"

def cdx_query(ticker, filter_dated=False):
    """
    Query Wayback CDX API for archived Yahoo Finance history pages.
    filter_dated=True: only snapshots with period1= in URL (has JSON blob)
    filter_dated=False: all snapshots
    """
    url_pattern = f"finance.yahoo.com/quote/{ticker}/history*"
    params = {
        "url": url_pattern,
        "output": "json",
        "fl": "timestamp,original,statuscode",
        "filter": "statuscode:200",
    }
    if filter_dated:
        params["filter"] = ["statuscode:200", "original:.*period1.*"]

    try:
        r = requests.get(CDX_BASE, params=params, timeout=20)
        if r.status_code == 200 and r.text.strip():
            rows = json.loads(r.text)
            if len(rows) > 1:  # first row is header
                return rows[1:]  # skip header
        return []
    except Exception as e:
        return []

def extract_date_range(url):
    """Extract period1/period2 unix timestamps from URL and convert to dates."""
    from datetime import datetime
    p1 = re.search(r'period1=(\d+)', url)
    p2 = re.search(r'period2=(\d+)', url)
    if p1 and p2:
        try:
            start = datetime.utcfromtimestamp(int(p1.group(1))).strftime('%Y-%m-%d')
            end   = datetime.utcfromtimestamp(int(p2.group(1))).strftime('%Y-%m-%d')
            return start, end
        except:
            pass
    return None, None

print("=" * 70)
print("Wayback Machine CDX Scan — Delisted Ticker Coverage Inventory")
print("=" * 70)

results = {}

for ticker, (company, delist_year, delist_type) in TICKERS.items():
    print(f"\n{ticker} [{delist_type} {delist_year}]")
    
    # All 200 snapshots
    all_snaps = cdx_query(ticker, filter_dated=False)
    # Snapshots with date range params (actually contain JSON price data)
    dated_snaps = cdx_query(ticker, filter_dated=True)
    
    entry = {
        "delist_year": delist_year,
        "delist_type": delist_type,
        "total_snapshots": len(all_snaps),
        "dated_snapshots": len(dated_snaps),
        "dated_urls": [],
    }
    
    print(f"  Total HTTP-200 snapshots: {len(all_snaps)}")
    print(f"  Snapshots with date params: {len(dated_snaps)}")
    
    if dated_snaps:
        # Show the date ranges covered
        ranges = []
        for row in dated_snaps:
            ts, url, status = row
            start, end = extract_date_range(url)
            if start:
                ranges.append((ts, start, end, url))
                entry["dated_urls"].append({"timestamp": ts, "start": start, "end": end, "url": url})
        
        if ranges:
            # Find overall coverage
            all_starts = [r[1] for r in ranges]
            all_ends   = [r[2] for r in ranges]
            print(f"  Price data coverage:")
            print(f"    Earliest period1: {min(all_starts)}")
            print(f"    Latest period2:   {max(all_ends)}")
            print(f"  Sample URLs:")
            for ts, start, end, url in ranges[:3]:
                print(f"    [{ts}] {start} → {end}")
    elif all_snaps:
        # Has snapshots but none with date params — old format, may have HTML table
        timestamps = [row[0] for row in all_snaps]
        print(f"  Snapshots span: {min(timestamps)[:8]} → {max(timestamps)[:8]}")
        print(f"  (No date-param URLs — pre-Redux format, JSON extraction unlikely)")
    else:
        print(f"  No coverage found")
    
    results[ticker] = entry
    time.sleep(1.5)  # Be polite to Wayback API

# ── Summary table ─────────────────────────────────────────────────────────────
print("\n" + "=" * 70)
print("SUMMARY")
print("=" * 70)
print(f"{'Ticker':<8} {'Year':<6} {'Type':<12} {'All Snaps':<12} {'Dated Snaps':<14} {'Usable?'}")
print("-" * 70)
for ticker, entry in results.items():
    usable = "YES" if entry["dated_snapshots"] > 0 else ("MAYBE" if entry["total_snapshots"] > 0 else "NO")
    print(f"{ticker:<8} {entry['delist_year']:<6} {entry['delist_type']:<12} {entry['total_snapshots']:<12} {entry['dated_snapshots']:<14} {usable}")

# Save full results
out = "/tmp/wayback_scan_results.json"
with open(out, "w") as f:
    json.dump(results, f, indent=2, default=str)
print(f"\nFull results saved to: {out}")