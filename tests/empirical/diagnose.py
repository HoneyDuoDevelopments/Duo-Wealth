"""
MacroTrends Diagnosis Round 4 — Final:
  1. Parse dataDaily for AAPL — confirm structure, fields, adjustment state
  2. Check AAPL 1980 prices vs known split history to determine adjustment state
  3. Confirm no delisted tickers exist under any ticker variant
"""
import requests, re, json, time

SESSION = requests.Session()
HEADERS = {
    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
    "Referer": "https://www.macrotrends.net/stocks/charts/AAPL/apple/stock-price-history",
    "Connection": "keep-alive",
}

# ── 1. Parse dataDaily ───────────────────────────────────────────────────────
print("=" * 60)
print("1. AAPL dataDaily — structure + fields + adjustment state")
print("=" * 60)

r = SESSION.get(
    "https://www.macrotrends.net/production/stocks/desktop/PRODUCTION/stock_price_history.php?t=AAPL&yb=50",
    headers=HEADERS, timeout=30
)
html = r.text

# dataDaily is the var name
m = re.search(r'var\s+dataDaily\s*=\s*(\[.*?\])\s*;', html, re.DOTALL)
if m:
    raw = m.group(1)
    print(f"dataDaily raw length: {len(raw)} chars")
    data = json.loads(raw)
    print(f"Row count: {len(data)}")
    print(f"First row: {data[0]}")
    print(f"Last row:  {data[-1]}")
    print(f"Fields: {list(data[0].keys()) if isinstance(data[0], dict) else type(data[0])}")
    
    # Adjustment state check:
    # AAPL IPO was Dec 12, 1980 at $22/share (unadjusted)
    # Split-adjusted (splits only) IPO price ≈ $0.10
    # Total-return adjusted (splits + divs) ≈ similar to split-adjusted for early years
    print(f"\n--- Adjustment State Check ---")
    print(f"AAPL IPO Dec 1980: unadjusted=$22, split-adj≈$0.10")
    early = [row for row in data if row.get('date','').startswith('1980')]
    if early:
        print(f"MacroTrends 1980 rows:")
        for row in early[:5]:
            print(f"  {row}")
    
    # Also check a known split date — June 9, 2014 4:1 split
    # Day before split: unadjusted ~$645, split-adj ~$92 (÷7 cumulative at that point)
    split_check = [row for row in data if '2014-06' in row.get('date','')]
    if split_check:
        print(f"\nJune 2014 rows (around 4:1 split on June 9):")
        for row in split_check[:5]:
            print(f"  {row}")
else:
    print("dataDaily NOT FOUND — checking what vars exist")
    # Try to find it with a looser pattern
    m2 = re.search(r'var\s+dataDaily\s*=\s*(.*?);[\r\n]', html, re.DOTALL)
    if m2:
        print(f"Loose match: {m2.group(1)[:200]}")

time.sleep(2)

# ── 2. Confirm delisted 500s aren't a Referer issue ─────────────────────────
print("\n" + "=" * 60)
print("2. CELG — try with correct company referer + LEH OTC ticker variant")
print("=" * 60)

# Try CELG with its own page as referer
for ticker, referer in [
    ("CELG", "https://www.macrotrends.net/stocks/charts/CELG/celgene/stock-price-history"),
    # Lehman had OTC ticker LEHMQ after bankruptcy
    ("LEHMQ", "https://www.macrotrends.net/stocks/charts/LEH/lehman-brothers/stock-price-history"),
    # Some delistings show up under different slugs
    ("TWX",  "https://www.macrotrends.net/stocks/charts/TWX/time-warner/stock-price-history"),
]:
    h = {**HEADERS, "Referer": referer}
    r2 = SESSION.get(
        f"https://www.macrotrends.net/production/stocks/desktop/PRODUCTION/stock_price_history.php?t={ticker}&yb=50",
        headers=h, timeout=15
    )
    dates = re.findall(r'(\d{4}-\d{2}-\d{2})', r2.text)
    earliest = min(dates) if dates else "?"
    print(f"  {ticker}: HTTP={r2.status_code} | len={len(r2.text)} | earliest={earliest}")
    time.sleep(1)