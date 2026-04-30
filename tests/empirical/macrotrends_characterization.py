"""
MacroTrends Characterization Harness
Phase 1A — Source Empirical Verification

Tests:
  Q1: Is price data accessible via plain requests (no browser)?
  Q2: What is the URL/endpoint structure for active vs delisted tickers?
  Q3: What adjustment state is the price data in?
  Q4: What OHLCV fields are available?
  Q5: What is the date coverage depth?
  Q6: What is the rate limit / blocking behavior?
  Q7: Do delisted tickers (CELG, LEH, BSC) have coverage?
"""

import requests
import re
import json
import time
from datetime import datetime

SESSION = requests.Session()
SESSION.headers.update({
    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
    "Accept-Encoding": "gzip, deflate, br",
    "Referer": "https://www.macrotrends.net/",
    "DNT": "1",
    "Connection": "keep-alive",
    "Upgrade-Insecure-Requests": "1",
})

# ── Ticker test set ──────────────────────────────────────────────────────────
TICKERS = {
    # Active
    "AAPL":  ("aapl", "apple",   "active",            "2000+"),
    "MSFT":  ("msft", "microsoft", "active",           "2000+"),
    # Post-2016 delistings (Wayback may also cover)
    "CELG":  ("celg", "celgene", "delisted_2019_acq",  "1990+"),
    "TWTR":  ("twtr", "twitter", "delisted_2022_acq",  "2013+"),
    "RHT":   ("rht",  "red-hat", "delisted_2019_acq",  "1999+"),
    # Pre-2016 delistings (Wayback cannot cover)
    "LEH":   ("leh",  "lehman-brothers", "delisted_2008_bk", "1994+"),
    "BSC":   ("bsc",  "bear-stearns",    "delisted_2008_acq","1985+"),
}

results = {}

def fetch_page(ticker_slug, company_slug):
    """Attempt to fetch MacroTrends stock price history page."""
    url = f"https://www.macrotrends.net/stocks/charts/{ticker_slug}/{company_slug}/stock-price-history"
    try:
        r = SESSION.get(url, timeout=20)
        return r, url
    except Exception as e:
        return None, url

def extract_price_data(html):
    """
    MacroTrends embeds price data as a JS variable in the page.
    Known patterns across different site versions:
      - var originalData = [...]
      - var chartData = [...]
      - data: [...]  inside a Highcharts config
    Returns (pattern_found, sample_rows, fields_present)
    """
    # Pattern 1: originalData (most common in older scrapers)
    m = re.search(r'var\s+originalData\s*=\s*(\[.*?\]);', html, re.DOTALL)
    if m:
        try:
            data = json.loads(m.group(1))
            return "originalData", data[:3], list(data[0].keys()) if data else []
        except Exception:
            return "originalData_parse_error", [], []

    # Pattern 2: chartData
    m = re.search(r'var\s+chartData\s*=\s*(\[.*?\]);', html, re.DOTALL)
    if m:
        try:
            data = json.loads(m.group(1))
            return "chartData", data[:3], list(data[0].keys()) if data else []
        except Exception:
            return "chartData_parse_error", [], []

    # Pattern 3: Highcharts series data
    m = re.search(r'"series"\s*:\s*\[.*?"data"\s*:\s*(\[\[.*?\]\])', html, re.DOTALL)
    if m:
        return "highcharts_series", [], ["date_ms", "value"]

    # Pattern 4: PHP endpoint JSON (some scrapers hit assets/php directly)
    if '"date"' in html and '"open"' in html:
        return "inline_json_unknown", [], []

    return None, [], []

def check_adjustment_state(sample_rows, ticker_slug):
    """
    Heuristic: compare first available price to known split-adjusted vs raw values.
    MacroTrends claims to show split+dividend adjusted prices.
    """
    # We'll check AAPL: raw 1980 price should be ~$0.10 if fully adjusted back,
    # or ~$28 if only showing post-split prices without full adjustment.
    # For now just return the raw values for manual inspection.
    if sample_rows:
        return sample_rows
    return []

# ── Q1/Q2: Basic accessibility + URL structure ───────────────────────────────
print("=" * 60)
print("Q1/Q2: Accessibility + URL Structure")
print("=" * 60)

for ticker, (slug, company, status, era) in TICKERS.items():
    r, url = fetch_page(slug, company)
    if r is None:
        print(f"  {ticker}: NETWORK ERROR")
        results[ticker] = {"status": "network_error"}
        continue

    entry = {
        "http_status": r.status_code,
        "content_length": len(r.text),
        "ticker_status": status,
        "era": era,
        "url": url,
    }

    if r.status_code == 200:
        pattern, sample, fields = extract_price_data(r.text)
        entry["data_pattern"] = pattern
        entry["fields"] = fields
        entry["sample_rows"] = sample

        # Check date range
        dates = re.findall(r'(\d{4}-\d{2}-\d{2})', r.text)
        if dates:
            entry["earliest_date_found"] = min(dates)
            entry["latest_date_found"] = max(dates)

        # Check if company name appears (confirms page loaded real content)
        entry["company_name_present"] = company.replace("-", " ") in r.text.lower()

        print(f"  {ticker} [{status}]: HTTP 200 | pattern={pattern} | fields={fields}")
        print(f"    date range in page: {entry.get('earliest_date_found','?')} → {entry.get('latest_date_found','?')}")
    elif r.status_code == 404:
        print(f"  {ticker} [{status}]: HTTP 404 — page does not exist")
    elif r.status_code == 403:
        print(f"  {ticker} [{status}]: HTTP 403 — blocked")
        entry["block_type"] = r.text[:100]
    else:
        print(f"  {ticker} [{status}]: HTTP {r.status_code}")

    results[ticker] = entry
    time.sleep(2)  # Be polite, also tests rate limiting

# ── Q6: Rate limit check ─────────────────────────────────────────────────────
print("\n" + "=" * 60)
print("Q6: Rate limit / blocking behavior")
print("=" * 60)
statuses = [v.get("http_status") for v in results.values()]
print(f"  Status distribution across {len(statuses)} requests: {dict((s, statuses.count(s)) for s in set(statuses))}")
print(f"  All blocked: {all(s == 403 for s in statuses)}")
print(f"  Any 429 (rate limit): {any(s == 429 for s in statuses)}")

# ── Q3/Q4/Q5: Adjustment state + fields + depth (from successful fetches) ────
print("\n" + "=" * 60)
print("Q3/Q4/Q5: Adjustment State + Fields + Date Depth")
print("=" * 60)

for ticker, entry in results.items():
    if entry.get("http_status") == 200 and entry.get("sample_rows"):
        print(f"\n  {ticker} sample rows:")
        for row in entry["sample_rows"]:
            print(f"    {row}")
        print(f"  Fields: {entry.get('fields')}")

# ── Q7: Delisted coverage summary ────────────────────────────────────────────
print("\n" + "=" * 60)
print("Q7: Delisted Coverage")
print("=" * 60)
for ticker, entry in results.items():
    status = TICKERS[ticker][2]
    if "delisted" in status:
        http = entry.get("http_status", "?")
        pattern = entry.get("data_pattern", "none")
        earliest = entry.get("earliest_date_found", "?")
        print(f"  {ticker} [{status}]: HTTP={http} | data={pattern} | earliest={earliest}")

# ── Save results ──────────────────────────────────────────────────────────────
out_path = "/tmp/macrotrends_characterization.json"
with open(out_path, "w") as f:
    # sample_rows may not be JSON serializable cleanly, handle it
    json.dump(results, f, indent=2, default=str)
print(f"\nFull results saved to: {out_path}")