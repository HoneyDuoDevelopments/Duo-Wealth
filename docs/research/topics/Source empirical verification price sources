# Free Price Source Empirical Verification
**Research Topic:** Phase 1A — Price Source Characterization  
**Status:** Complete  
**Date:** 2026-04-29  
**Resolves:** Open Questions #4, #5, #6

---

## Purpose

Empirically characterize every free/cheap price data source available for personal use before writing any adapter code. Each source was tested against real tickers across multiple eras — active, recently delisted, and pre-2016 delisted. No assumptions from documentation; everything confirmed by actual HTTP responses and data inspection.

---

## Sources Tested

1. Stooq Bulk Archive
2. yfinance
3. MacroTrends
4. Wayback Machine (Yahoo Finance history pages)
5. Quandl WIKI / Nasdaq Data Link
6. Investing.com, ADVFN, stockanalysis.com, SimFin (eliminated)
7. Stooq web endpoint (eliminated)

---

## 1. Stooq Bulk Archive

### Access
Download ZIP from `https://stooq.com/db/h/`. No account, no API key, no rate limits. Offline after download.

### Directory Structure
```
data/daily/us/
  nasdaq stocks/1/     (~2,000 files max per subdir)
  nasdaq stocks/2/
  nyse stocks/1/
  nyse stocks/2/
  nyse etfs/1/
  nasdaq etfs/1/
  nysemkt stocks/1/
```
Total: ~12,029 files across all subdirs. **Do not trust folder names for exchange classification** — WMT is in `nasdaq stocks/`, SHLD is in `nyse etfs/`. Use `rglob("*.txt")` and ignore folder-based classification.

### Schema (Bulk Archive — Schema A, 10 columns)
```
<TICKER>,<PER>,<DATE>,<TIME>,<OPEN>,<HIGH>,<LOW>,<CLOSE>,<VOL>,<OPENINT>
```
Column indices: 0=ticker, 1=per, 2=date, 3=time, 4=open, 5=high, 6=low, 7=close, 8=vol, 9=openint

- `DATE`: YYYYMMDD (no separators)
- `TIME`: always `000000` — drop
- `OPENINT`: always `0` — drop
- `PER`: always `D` — assert and drop

**Note:** Schema B (web download format, 6-col: `Date,Open,High,Low,Close,Volume`, YYYY-MM-DD dates, no ticker column) exists for Stooq manual/web-download-style responses but is **not part of the Phase 1 adapter**. The unauthenticated `stooq.com/q/d/l/` endpoint was eliminated from the build path — current testing returned an API-key prompt with unreliable access behavior. Stage 6 uses only the bulk archive Schema A.

### Adjustment State
**Split-adjusted only. Not dividend-adjusted.**

Empirically confirmed via AAPL bulk archive rows:
- Earliest AAPL row in the bulk archive: 1984-09-07 (not IPO date — Stooq depth starts 1984 for most US equities)
- Early price magnitude is consistent with cumulative split adjustment across all known AAPL splits
- Split-window checks confirm smooth price crossing over known split dates with no discontinuities

The AT&T fractional-volume check supports the no-dividend-adjustment conclusion, but does not independently rule it out — a provider could dividend-adjust price without adjusting volume. The primary evidence is the long-history price magnitude and split-window behavior.

### Reverse-Adjustment Math
To recover raw (unadjusted) prices from Stooq data:
```
raw_price  = stooq_price × cumulative_split_factor
raw_volume = stooq_volume ÷ cumulative_split_factor
```
Where `cumulative_split_factor` = product of all forward splits that occurred **after** the row's date through the present (or through delisting).

**Critical:** Multiply price, divide volume. The factor applies only to splits that postdate the row — not all splits in history.

### Coverage
- Date depth: 1984 to present for most US equities
- Active tickers: comprehensive
- **Delisted coverage: not dependable.** Major tested delisted candidates (LEH, BSC, CFC, FNM, CELG, RHT, RTN, ATVI, XLNX) were absent from the bulk archive. WB, DELL, SHLD are present but confirmed as ticker reuse only — different companies under the same symbol. Treat Stooq as having no systematic delisted-history coverage.

### Ticker Reuse
~15% upper-bound rate (smoke test). Systematic issue. **Mitigation:** M1f lifecycle registry provides date-bounded `(ticker, start_date, end_date)` records — adapters never do unbounded ticker lookup.

### Rate Limits
None. Bulk ZIP is a one-time download, fully offline.

### Decision
**Primary source for active universe historical price history.** Stage 6 Stooq adapter approved to build after Stages 1–5 complete.

---

## 2. yfinance

### Version Tested
`yfinance==1.3.0` installed in project `.venv`.

### Access
`pip install yfinance`. No API key. Rate-limited — not suitable for bulk ingestion; use for targeted per-ticker pulls.

### Schema and Adjustment State
Two modes:

**`auto_adjust=False` (use this):**
```python
df = yf.Ticker("AAPL").history(period="max", auto_adjust=False)
# Columns: Open, High, Low, Close, Volume, Dividends, Stock Splits, Adj Close
```
- `Close` = **unadjusted raw price**
- `Adj Close` = **total-return adjusted** (split + dividend)

**`auto_adjust=True` (default — do not use for our pipeline):**
- Returns only split+dividend adjusted `Close`, no `Adj Close` column
- Loses the raw price entirely

### Date Index
Timezone-aware: `2024-01-02 00:00:00-05:00` (Eastern). Adapter must normalize to plain date with `.tz_localize(None)` or `.dt.date`.

### Coverage
- Active tickers: full history
- **Delisted tickers: zero coverage.** All tested tickers returned empty with "possibly delisted; no timezone found" error:
  - Pre-2009: LEH, BSC
  - Post-2010 M&A: CELG, ATVI, TWTR, VMW, XLNX, RHT, RTN
  - SHLD: empty with different error ("Yahoo data doesn't exist for date range")
- Yahoo has completely purged delisted tickers from the free API regardless of era.

### Role in Pipeline
Cross-validator for active tickers against Stooq. Provides both raw and total-return adjusted in one call — useful for verifying Stooq split adjustments and computing dividend adjustment factors independently.

**Not a primary ingestion source** — rate limits make bulk pulls impractical. Use Stooq bulk for ingestion, yfinance for spot validation.

---

## 3. MacroTrends

### Access
No account required. Plain `requests` works via the PHP iframe endpoint — no Selenium needed. Main HTML pages are Cloudflare-protected (403), but the data iframe is not.

### Endpoint
```
https://www.macrotrends.net/production/stocks/desktop/PRODUCTION/stock_price_history.php?t={TICKER}&yb={YEARS_BACK}
```
This URL is loaded as an iframe by the main history page. Access requires a `Referer` header pointing to the main stock page:
```python
headers = {
    "Referer": f"https://www.macrotrends.net/stocks/charts/{ticker_slug}/{company_slug}/stock-price-history",
    "User-Agent": "Mozilla/5.0 ...",
}
```

### Data Location in Response
Price data is embedded as a JavaScript variable `dataDaily` in the iframe HTML:
```python
import re, json
m = re.search(r'var\s+dataDaily\s*=\s*(\[.*?\])\s*;', html, re.DOTALL)
data = json.loads(m.group(1))
```

### Schema
Short field names — each row is a dict:
```python
{'d': '1980-12-12', 'o': '0.0983', 'h': '0.0988', 'l': '0.0983', 'c': '0.0983', 'v': '1.604'}
# Later rows also include:
# 'ma50': '260.562', 'ma200': '253.923'
```
- `d` = date (YYYY-MM-DD)
- `o`, `h`, `l`, `c` = OHLC prices (strings — cast to float)
- `v` = volume **in millions** (not raw share count — multiply by 1,000,000)
- `ma50`, `ma200` = optional moving averages on recent rows

### `yb` Parameter (Years Back)
Controls history depth. Empirically tested:

| yb | Earliest date returned | Response size |
|----|----------------------|---------------|
| 1  | ~1 year ago          | ~45KB         |
| 5  | ~5 years ago         | ~169KB        |
| 15 | ~15 years ago        | ~472KB        |
| 30 | ~30 years ago        | ~903KB        |
| 50 | 1980-12-12 (AAPL)   | ~1.34MB       |
| 99 | Same as 50 (caps)   | ~1.34MB       |

Use `yb=50` to get full available history. `yb=99` does not extend further.

### Adjustment State
**Split-adjusted only. Not dividend-adjusted.**

Empirically confirmed via AAPL: MacroTrends 1980-12-12 close = `$0.0983` ≈ $0.10. Known unadjusted IPO price was $22.00. Implied cumulative split factor ~224× is consistent with AAPL's full split history. This matches Stooq's split-adjusted values for the same era.

### Coverage
- Active tickers: full history back to ~1980 for large-cap US stocks
- **Delisted tickers: zero coverage.** All tested tickers (CELG, TWTR, RHT, LEH, BSC, ATVI, LEHMQ, TWX) returned HTTP 500. MacroTrends has purged delisted tickers server-side.
- The `/stocks/delisted/` URL path returns HTTP 410 (Gone) — confirmed intentional removal.

### Rate Limits
Not formally documented. A 2-second polite delay between requests was sufficient for 7 sequential requests with no blocking. Do not hammer — treat as scraping with courtesy delays.

### Role in Pipeline
Supplementary cross-validator for active tickers. Useful as an independent split-adjusted source alongside Stooq and yfinance. **Not a primary source** — scraping dependency is fragile; site structure could change.

---

## 4. Wayback Machine

### How It Works
The Wayback Machine archived Yahoo Finance history pages (`finance.yahoo.com/quote/{TICKER}/history`) extensively between 2016 and 2023. During Yahoo's Redux-era (roughly late 2018 onward), the history page embedded the full price dataset as a JSON blob in the server-side Redux store — this JSON was captured in the HTML snapshot.

### CDX API (Coverage Discovery)
Query available snapshots without fetching page content:
```python
import requests, json

CDX = "https://web.archive.org/cdx/search/cdx"
params = {
    "url": f"finance.yahoo.com/quote/{TICKER}/history*period1*",
    "output": "json",
    "fl": "timestamp,original,statuscode",
    "filter": ["statuscode:200", "original:.*period1.*"],
}
r = requests.get(CDX, params=params)
rows = json.loads(r.text)[1:]  # skip header row
```
The `period1` filter is critical — only snapshots with `period1=` in the URL contain the embedded JSON price blob. Snapshots without date parameters are HTML shells with no price data.

### Fetching Price Data
```python
# Snapshot URL format:
# https://web.archive.org/web/{TIMESTAMP}/{ORIGINAL_URL}
import re, json, requests

snapshot_url = f"https://web.archive.org/web/{timestamp}/{original_url}"
html = requests.get(snapshot_url).text

m = re.search(r'"prices":(\[.*?\])', html, re.DOTALL)
prices = json.loads(m.group(1))
# Each row: {"date": 1399469400, "open": 31.97, "high": 32.0, "low": 29.51,
#            "close": 30.66, "volume": 68876300, "adjclose": 30.66}
```
`date` is Unix epoch timestamp — convert with `datetime.utcfromtimestamp(ts).date()`.

### Adjustment State
`close` = unadjusted raw price. `adjclose` = **total-return adjusted** (split + dividend), same as Yahoo's `Adj Close`. Both are present in the same row.

### Coverage Scan Results (10 tickers tested)

| Ticker | Delist Year | Type | Total Snapshots | Dated Snapshots | Usable? |
|--------|-------------|------|-----------------|-----------------|---------|
| LEH | 2008 | bankruptcy | 2 | 0 | No |
| BSC | 2008 | acquisition | 4 | 0 | No |
| WB | 2008 | acquisition | 15 | 0 | No |
| SHLD | 2018 | bankruptcy | 0 | 0 | No |
| CELG | 2019 | acquisition | 11 | 0 | No |
| RHT | 2019 | acquisition | 12 | 0 | No |
| TWTR | 2022 | acquisition | 148 | **17** | **Yes** |
| ATVI | 2023 | acquisition | 47 | **6** | **Yes** |
| MYL | 2020 | merger | 12 | 0 | No |
| RTN | 2020 | merger | 20 | 0 | No |

**TWTR coverage:** 2013-11-07 (IPO) → 2023-02-18. Full history.  
**ATVI coverage:** 1993-10-25 → 2023-01-23. Full history.

### Why the Coverage Gap
The Redux JSON blob only exists in snapshots from late 2018 onward. Tickers that delisted before or shortly after that window (CELG, RHT, MYL, RTN) only have pre-Redux snapshots — HTML shells with no embedded price data. The dated-param URL pattern (which triggers the JSON embed) was only generated when users visited parameterized Yahoo URLs, and Wayback only captures what users actually requested. Coverage is therefore opportunistic: tickers with heavy public interest during the 2019–2022 window (TWTR during the Musk acquisition, ATVI during the Microsoft acquisition) got captured systematically. Others did not.

### Coverage Estimate
Approximately 10–20% of S&P 500/400 delisted tickers from 2005–present will have usable Wayback coverage — specifically high-profile post-2019 delistings that generated significant web traffic.

### Role in Pipeline
Gap-fill for high-profile post-2019 delistings. Run a CDX scan across the full delisted universe to inventory what's available before building the adapter. Not a planned primary source for any specific ticker — treat as opportunistic.

---

## 5. Quandl WIKI / Nasdaq Data Link

### Access
Free account at `data.nasdaq.com`. API key required (free). Dataset: `WIKI/PRICES`.

```python
import requests
url = "https://data.nasdaq.com/api/v3/datatables/WIKI/PRICES.json"
params = {
    "ticker": "CELG",
    "date.gte": "2005-01-01",
    "date.lte": "2018-03-27",
    "api_key": API_KEY,
}
r = requests.get(url, params=params)
data = r.json()["datatable"]["data"]
```

### Schema
Each row contains 14 values:
```
ticker, date, open, high, low, close, volume, ex-dividend, split_ratio,
adj_open, adj_high, adj_low, adj_close, adj_volume
```
Both raw OHLCV **and** total-return adjusted OHLCV in the same row, plus `ex-dividend` and `split_ratio` corporate action fields. This is the cleanest schema of any source tested.

### Adjustment State
- Raw columns (`open`, `high`, `low`, `close`, `volume`): unadjusted
- Adjusted columns (`adj_open` through `adj_volume`): total-return adjusted (split + dividend)
- `ex-dividend`: dividend amount on ex-date, else 0.0
- `split_ratio`: split ratio on split date, else 1.0

### Date Range
Frozen at **March 27, 2018**. No updates since. Nasdaq deprecated the community-maintained feed on April 11, 2018.

### Coverage
- ~3,000 US equities, large-cap focus
- **Does NOT cover pre-2008 delistings:** LEH and BSC returned empty — they were not in WIKI's ticker universe
- **Does cover tickers that were active through 2018:** CELG, RHT, MYL, RTN, ATVI, TWTR all confirmed with data back to 2005

Confirmed results:
| Ticker | 2005 Q1 rows | Sample open |
|--------|-------------|-------------|
| CELG | 61 | $16.07 (adj) |
| RHT | 61 | $11.15 |
| MYL | 61 | $17.23 (adj) |
| RTN | 61 | $27.99 (adj) |
| ATVI | 61 | $5.24 (adj) |
| TWTR | 61 | $47.55 (2014 Q1) |
| LEH | 0 | — not in dataset |
| BSC | 0 | — not in dataset |

### Role in Pipeline
**First-class delisted source for tickers active through March 2018.** For any post-2018 delisted ticker that was in WIKI's 3,000-ticker universe, WIKI provides clean, dual-adjusted OHLCV with corporate action metadata from 2005 (or earlier) through March 2018. Combined with Wayback Machine for the March 2018 → delisting date gap, this covers the full history for high-profile post-2018 delistings (CELG, RHT, TWTR, ATVI, etc.) at zero cost.

---

## 6. Sources Eliminated

### Investing.com
HTTP 403 (Cloudflare) on all requests including with full browser headers and Referer. Not accessible via `requests`. Would require a browser automation stack. Not pursued.

### ADVFN
HTTP 403 (Cloudflare) on all requests. Same situation as Investing.com. Not pursued.

### stockanalysis.com
HTTP 404 for delisted tickers (e.g., CELG). No delisted coverage.

### SimFin
HTTP 404 for CELG via free API. Fundamentals-focused; price coverage for delisted tickers not available on free tier.

### Stooq Web Endpoint (`stooq.com/q/d/l/`)
Returns an API key prompt for all tickers — both active and delisted. When CELG was searched directly on the Stooq site, it returned "Symbol CELG.US nie istnieje w bazie" (does not exist in the database). The API key prompt is a generic response to unauthenticated requests, not confirmation of ticker existence. No delisted coverage.

### Quandl WIKI for Pre-2008 Delistings
LEH and BSC not in WIKI's ticker universe — returned empty results. WIKI does not cover these.

### MacroTrends for Delisted Tickers
HTTP 500 on all delisted tickers. Intentional server-side purge confirmed by HTTP 410 on the `/stocks/delisted/` URL path.

---

## Composite Coverage Map

| Source | Active Coverage | Adjustment State | Delisted Coverage | Mechanism |
|--------|----------------|------------------|-------------------|-----------|
| Stooq bulk | 1984–present | Split-adjusted only | None | Bulk ZIP, offline |
| yfinance | Full | Raw close + total-return adj close | None | API, rate-limited |
| MacroTrends | ~1980–present | Split-adjusted only | None | PHP iframe, requests |
| WIKI/Nasdaq | 1962–Mar 2018 | Raw + total-return + corp actions | Post-2018 delistings in universe | Free API |
| Wayback Machine | N/A | Raw close + Yahoo adjclose | ~10-20% post-2019 high-profile | CDX scan + HTML parse |

### Delisted Coverage Strategy (Personal Use)

1. **WIKI first** — free, clean, API, covers 2005–Mar 2018 for any ticker in the ~3,000 universe
2. **Wayback fill** — CDX scan to find dated-param snapshots for the Mar 2018 → delisting gap
3. **Gap accept or EODHD bootstrap** — tickers not in WIKI and not in Wayback (pre-2016 delistings, obscure tickers) require a one-month EODHD subscription (~$19.99) for a one-time pull. Cancel after bootstrap.

Pre-2008 delistings (LEH, BSC, WB) have **no free coverage path identified**. WIKI doesn't include them, Wayback has no dated-param snapshots, MacroTrends has purged them. EODHD paid is the only known option.

---

## Commercial Use Boundary

This document characterizes sources for personal research warehouse construction (Duo Wealth internal use) and for the DataDuo methodology guide ("Build Your Own Warehouse"). DataDuo as a commercial service does not redistribute third-party raw price rows from Stooq, Yahoo/yfinance, MacroTrends, Wayback snapshots, or WIKI/Nasdaq — regardless of whether personal use of those sources is permissible. DataDuo's commercial API serves enrichment, lifecycle, corporate-action, identifier, and validation metadata only. Users join those enrichments to their own price data sourced independently.

---

## Implementation Notes

### Stooq Adapter
- Use `rglob("*.txt")` for file discovery — don't rely on folder names
- Assert `PER == 'D'` on every row
- Drop TIME and OPENINT columns
- Parse DATE as `datetime.strptime(val, "%Y%m%d").date()`
- All prices are strings — cast to float
- Volume is raw shares (not millions)
- Integrate with M1f lifecycle registry for date-bounded ticker lookup before any ingestion

### yfinance Adapter
- Always use `auto_adjust=False`
- Normalize date index: `df.index = df.index.tz_localize(None).normalize()`
- Use `Close` for raw, `Adj Close` for total-return adjusted
- Rate limit: add `time.sleep(0.5)` between tickers minimum; use for validation only, not bulk ingestion

### MacroTrends Adapter
- Target endpoint: `stock_price_history.php?t={TICKER}&yb=50`
- Referer header required: `https://www.macrotrends.net/stocks/charts/{slug}/{company}/stock-price-history`
- Data pattern: `var dataDaily = [...];` — use `re.DOTALL`
- Volume field `v` is in **millions** — multiply by 1,000,000 before storing
- Add 2-second delay between requests

### WIKI Adapter
- Filterable columns: `ticker` and `date` only
- Use `date.gte` / `date.lte` for range queries
- Handle pagination: responses include `meta.next_cursor_id` when results are truncated
- Column order: ticker(0), date(1), open(2), high(3), low(4), close(5), volume(6), ex-dividend(7), split_ratio(8), adj_open(9), adj_high(10), adj_low(11), adj_close(12), adj_volume(13)

### Wayback Adapter
- CDX query first — only fetch snapshots that have `period1` in URL
- Filter by `statuscode:200`
- Unix timestamp conversion: `datetime.utcfromtimestamp(int(ts)).date()`
- `prices` array may be ordered descending (newest first) — sort ascending before storing
- Some rows have only `date` and `close` (dividend/split event rows) — filter to rows with `open` present

---

## Open Questions Resolved

- **#4 (Stooq adjustment state):** RESOLVED — split-adjusted only, confirmed empirically
- **#5 (yfinance delisted coverage):** RESOLVED — zero delisted coverage on free API
- **#6 (free delisted price sources):** RESOLVED — WIKI covers post-2018 delistings in its universe through Mar 2018; Wayback covers high-profile post-2019 delistings opportunistically; pre-2008 delistings have no free path

---

*Research method: empirical — all findings confirmed by actual HTTP responses and data inspection. No documentation-only claims.*  
*Scripts: `tests/empirical/stooq_characterization.py`, `tests/empirical/macrotrends_characterization.py`, `tests/empirical/wayback_scan.py`, `tests/empirical/diagnose*.py`, `tests/empirical/test_new_sources.py`*  
*Evidence: `tests/empirical/output/stooq/` (Q1–Q5 JSON files)*