\echo '============================================================'
\echo 'Stage 1 Identity Spine Load Verification'
\echo '============================================================'

\echo ''
\echo '0. Baseline row counts'
SELECT 'instrument_master' AS table_name, COUNT(*) AS row_count FROM instrument_master
UNION ALL
SELECT 'ticker_identifier_history', COUNT(*) FROM ticker_identifier_history
UNION ALL
SELECT 'universe_membership', COUNT(*) FROM universe_membership
ORDER BY table_name;

\echo ''
\echo '1. instrument_master rows where born_date > death_date'
SELECT COUNT(*) AS bad_rows
FROM instrument_master
WHERE born_date IS NOT NULL
  AND death_date IS NOT NULL
  AND born_date > death_date;

SELECT instrument_id, born_date, death_date, lifecycle_status, source_confidence, notes
FROM instrument_master
WHERE born_date IS NOT NULL
  AND death_date IS NOT NULL
  AND born_date > death_date
ORDER BY born_date
LIMIT 25;

\echo ''
\echo '2. ticker_identifier_history rows where date_from > date_to'
SELECT COUNT(*) AS bad_rows
FROM ticker_identifier_history
WHERE date_to IS NOT NULL
  AND date_from > date_to;

SELECT ticker_id, instrument_id, raw_ticker, normalized_ticker, source_ticker,
       exchange, date_from, date_to, source_name, source_confidence
FROM ticker_identifier_history
WHERE date_to IS NOT NULL
  AND date_from > date_to
ORDER BY normalized_ticker, date_from
LIMIT 25;

\echo ''
\echo '3. universe_membership rows where date_from > date_to'
SELECT COUNT(*) AS bad_rows
FROM universe_membership
WHERE date_to IS NOT NULL
  AND date_from > date_to;

SELECT membership_id, instrument_id, universe_code, date_from, date_to,
       source_name, source_confidence
FROM universe_membership
WHERE date_to IS NOT NULL
  AND date_from > date_to
ORDER BY universe_code, date_from
LIMIT 25;

\echo ''
\echo '4. source_confidence counts by table'
SELECT 'instrument_master' AS table_name, source_confidence::text, COUNT(*) AS row_count
FROM instrument_master
GROUP BY source_confidence

UNION ALL

SELECT 'ticker_identifier_history', source_confidence::text, COUNT(*)
FROM ticker_identifier_history
GROUP BY source_confidence

UNION ALL

SELECT 'universe_membership', source_confidence::text, COUNT(*)
FROM universe_membership
GROUP BY source_confidence

ORDER BY table_name, source_confidence;

\echo ''
\echo '5. universe_membership rows with NULL date_to currently active'
SELECT COUNT(*) AS active_membership_rows
FROM universe_membership
WHERE date_to IS NULL;

SELECT universe_code, COUNT(*) AS active_membership_rows
FROM universe_membership
WHERE date_to IS NULL
GROUP BY universe_code
ORDER BY universe_code;

\echo ''
\echo '6. Tickers appearing more than twice in ticker_identifier_history'
SELECT normalized_ticker,
       COUNT(*) AS interval_count,
       MIN(date_from) AS first_date,
       MAX(COALESCE(date_to, DATE '9999-12-31')) AS last_date_or_active,
       STRING_AGG(
         date_from::text || '→' || COALESCE(date_to::text, 'ACTIVE'),
         ', '
         ORDER BY date_from
       ) AS intervals
FROM ticker_identifier_history
GROUP BY normalized_ticker
HAVING COUNT(*) > 2
ORDER BY interval_count DESC, normalized_ticker;

\echo ''
\echo '7A. Hard-case raw rows'
SELECT tih.normalized_ticker,
       tih.raw_ticker,
       tih.source_ticker,
       tih.instrument_id,
       im.issuer_id,
       tih.date_from,
       tih.date_to,
       im.born_date,
       im.death_date,
       im.lifecycle_status,
       tih.source_confidence
FROM ticker_identifier_history tih
JOIN instrument_master im
  ON im.instrument_id = tih.instrument_id
WHERE UPPER(tih.normalized_ticker) IN ('GOOG', 'GOOGL', 'DELL', 'CELG', 'AAPL')
ORDER BY tih.normalized_ticker, tih.date_from;

\echo ''
\echo '7B. Hard-case PASS/FAIL checks'
WITH
goog AS (
    SELECT instrument_id
    FROM ticker_identifier_history
    WHERE UPPER(normalized_ticker) = 'GOOG'
      AND date_to IS NULL
    LIMIT 1
),
googl AS (
    SELECT instrument_id
    FROM ticker_identifier_history
    WHERE UPPER(normalized_ticker) = 'GOOGL'
      AND date_to IS NULL
    LIMIT 1
),
checks AS (
    SELECT
        'GOOG active, no end date' AS check_name,
        CASE WHEN EXISTS (
            SELECT 1
            FROM ticker_identifier_history
            WHERE UPPER(normalized_ticker) = 'GOOG'
              AND date_to IS NULL
        ) THEN 'PASS' ELSE 'FAIL' END AS status,
        (
            SELECT STRING_AGG(date_from::text || '→' || COALESCE(date_to::text, 'ACTIVE'), ', ')
            FROM ticker_identifier_history
            WHERE UPPER(normalized_ticker) = 'GOOG'
        ) AS detail

    UNION ALL

    SELECT
        'GOOGL active, no end date',
        CASE WHEN EXISTS (
            SELECT 1
            FROM ticker_identifier_history
            WHERE UPPER(normalized_ticker) = 'GOOGL'
              AND date_to IS NULL
        ) THEN 'PASS' ELSE 'FAIL' END,
        (
            SELECT STRING_AGG(date_from::text || '→' || COALESCE(date_to::text, 'ACTIVE'), ', ')
            FROM ticker_identifier_history
            WHERE UPPER(normalized_ticker) = 'GOOGL'
        )

    UNION ALL

    SELECT
        'GOOG and GOOGL have different instrument_id',
        CASE WHEN
            (SELECT instrument_id FROM goog) IS NOT NULL
            AND (SELECT instrument_id FROM googl) IS NOT NULL
            AND (SELECT instrument_id FROM goog) <> (SELECT instrument_id FROM googl)
        THEN 'PASS' ELSE 'FAIL' END,
        'GOOG=' || COALESCE((SELECT instrument_id::text FROM goog), 'MISSING')
        || ', GOOGL=' || COALESCE((SELECT instrument_id::text FROM googl), 'MISSING')

    UNION ALL

    SELECT
        'DELL exactly 2 rows',
        CASE WHEN (
            SELECT COUNT(*)
            FROM ticker_identifier_history
            WHERE UPPER(normalized_ticker) = 'DELL'
        ) = 2 THEN 'PASS' ELSE 'FAIL' END,
        (
            SELECT 'count=' || COUNT(*)::text
            FROM ticker_identifier_history
            WHERE UPPER(normalized_ticker) = 'DELL'
        )

    UNION ALL

    SELECT
        'DELL has 1996→2013 interval',
        CASE WHEN EXISTS (
            SELECT 1
            FROM ticker_identifier_history
            WHERE UPPER(normalized_ticker) = 'DELL'
              AND date_from = DATE '1996-09-06'
              AND date_to = DATE '2013-10-29'
        ) THEN 'PASS' ELSE 'FAIL' END,
        (
            SELECT STRING_AGG(date_from::text || '→' || COALESCE(date_to::text, 'ACTIVE'), ', ')
            FROM ticker_identifier_history
            WHERE UPPER(normalized_ticker) = 'DELL'
        )

    UNION ALL

    SELECT
        'DELL has 2024→active interval',
        CASE WHEN EXISTS (
            SELECT 1
            FROM ticker_identifier_history
            WHERE UPPER(normalized_ticker) = 'DELL'
              AND date_from = DATE '2024-09-23'
              AND date_to IS NULL
        ) THEN 'PASS' ELSE 'FAIL' END,
        (
            SELECT STRING_AGG(date_from::text || '→' || COALESCE(date_to::text, 'ACTIVE'), ', ')
            FROM ticker_identifier_history
            WHERE UPPER(normalized_ticker) = 'DELL'
        )

    UNION ALL

    SELECT
        'CELG end date = 2019-11-21',
        CASE WHEN EXISTS (
            SELECT 1
            FROM ticker_identifier_history
            WHERE UPPER(normalized_ticker) = 'CELG'
              AND date_to = DATE '2019-11-21'
        ) THEN 'PASS' ELSE 'FAIL' END,
        (
            SELECT STRING_AGG(date_from::text || '→' || COALESCE(date_to::text, 'ACTIVE'), ', ')
            FROM ticker_identifier_history
            WHERE UPPER(normalized_ticker) = 'CELG'
        )

    UNION ALL

    SELECT
        'AAPL active, no end date',
        CASE WHEN EXISTS (
            SELECT 1
            FROM ticker_identifier_history
            WHERE UPPER(normalized_ticker) = 'AAPL'
              AND date_to IS NULL
        ) THEN 'PASS' ELSE 'FAIL' END,
        (
            SELECT STRING_AGG(date_from::text || '→' || COALESCE(date_to::text, 'ACTIVE'), ', ')
            FROM ticker_identifier_history
            WHERE UPPER(normalized_ticker) = 'AAPL'
        )
)
SELECT *
FROM checks
ORDER BY check_name;

\echo ''
\echo '8. Optional: currently active S&P 500 membership sample'
SELECT tih.normalized_ticker,
       um.date_from,
       um.date_to,
       um.instrument_id
FROM universe_membership um
JOIN ticker_identifier_history tih
  ON tih.instrument_id = um.instrument_id
WHERE um.universe_code = 'SP500'
  AND um.date_to IS NULL
ORDER BY tih.normalized_ticker
LIMIT 25;

\echo ''
\echo 'Verification complete.'
