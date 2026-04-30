"""
Test Investing.com, ADVFN, and stockinvest.us for delisted CELG price data.
"""
import requests, re, time

SESSION = requests.Session()
SESSION.headers.update({
    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
    "Connection": "keep-alive",
})

def probe(label, url, extra_headers=None):
    h = dict(SESSION.headers)
    if extra_headers:
        h.update(extra_headers)
    try:
        r = requests.get(url, headers=h, timeout=15)
        html = r.text
        # Look for date patterns near price data
        date_hits = re.findall(r'\d{4}-\d{2}-\d{2}', html)
        # Also look for US date format MM/DD/YYYY common on finance sites
        us_date_hits = re.findall(r'\d{2}/\d{2}/\d{4}', html)
        # Look for price-like numbers near dates
        price_hits = re.findall(r'(?:open|high|low|close|price)["\s:]+(\d+\.\d+)', html, re.IGNORECASE)
        
        earliest_iso = min(date_hits) if date_hits else "?"
        earliest_us  = min(us_date_hits, key=lambda d: d[6:]+d[:2]+d[3:5]) if us_date_hits else "?"
        
        print(f"\n[{label}]")
        print(f"  URL: {url}")
        print(f"  Status: {r.status_code} | Length: {len(html)}")
        print(f"  ISO dates found: {len(date_hits)} | earliest: {earliest_iso}")
        print(f"  US dates found:  {len(us_date_hits)} | earliest: {earliest_us}")
        print(f"  Price values:    {price_hits[:5]}")
        if r.status_code == 200 and len(html) > 5000:
            # Print a snippet around the first date mention
            for d in (date_hits[:1] + us_date_hits[:1]):
                idx = html.find(d)
                if idx > 0:
                    print(f"  Context around '{d}': {repr(html[max(0,idx-60):idx+80])}")
    except Exception as e:
        print(f"\n[{label}] ERROR: {e}")

# ── Investing.com CELG historical data ──────────────────────────────────────
probe(
    "Investing.com CELG historical",
    "https://www.investing.com/equities/celgene-corp-historical-data",
    {"Referer": "https://www.investing.com/"}
)
time.sleep(2)

# ── ADVFN CELG historical ────────────────────────────────────────────────────
probe(
    "ADVFN CELG historical",
    "https://www.advfn.com/stock-market/NASDAQ/CELG/historical",
    {"Referer": "https://www.advfn.com/"}
)
time.sleep(2)

# ── stockanalysis.com - has a delisted section ───────────────────────────────
probe(
    "stockanalysis CELG",
    "https://stockanalysis.com/stocks/celg/history/",
    {"Referer": "https://stockanalysis.com/"}
)
time.sleep(2)

# ── wisesheets or simfin bulk download ───────────────────────────────────────
# SimFin has free bulk download - check if delisted tickers are in it
probe(
    "SimFin bulk prices US",
    "https://simfin.com/api/v2/companies/prices/compact?ticker=CELG&api-key=free",
    {}
)
time.sleep(2)

# ── stooq direct endpoint check for delisted (already know bulk doesn't have it)
# But their web endpoint might differ from the bulk
probe(
    "Stooq web CELG",
    "https://stooq.com/q/d/l/?s=celg.us&i=d",
    {"Referer": "https://stooq.com/"}
)