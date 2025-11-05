-- qc_checks.sql
-- Quality checks for Onboarding Pricing — Active Selection per Payment
-- These queries help validate timeline integrity, join correctness, and fee computations.
-- ANSI-ish; adjust DATEADD/INTERVAL syntax per engine where noted.

/* 1) Overlapping ranges in CUSTOM pricing per (customer_id, payment_method_id)
   Expectation: 0 rows
*/
WITH spans AS (
  SELECT
    customer_id,
    payment_method_id,
    starts_at,
    COALESCE(ends_at, DATE '9999-12-31') AS ends_at_norm
  FROM custom_pricing
),
overlaps AS (
  SELECT
    a.customer_id,
    a.payment_method_id,
    a.starts_at AS a_starts_at,
    a.ends_at_norm AS a_ends_at,
    b.starts_at AS b_starts_at,
    b.ends_at_norm AS b_ends_at
  FROM spans a
  JOIN spans b
    ON a.customer_id = b.customer_id
   AND a.payment_method_id = b.payment_method_id
   AND (a.starts_at, a.ends_at_norm) <> (b.starts_at, b.ends_at_norm)
   AND a.starts_at <= b.ends_at_norm
   AND b.starts_at <= a.ends_at_norm
)
SELECT * FROM overlaps
ORDER BY customer_id, payment_method_id, a_starts_at;

/* 2) Overlapping ranges in DEFAULT pricing per payment_method_id
   Expectation: 0 rows
*/
WITH spans AS (
  SELECT
    payment_method_id,
    starts_at,
    COALESCE(ends_at, DATE '9999-12-31') AS ends_at_norm
  FROM default_pricing
),
overlaps AS (
  SELECT
    a.payment_method_id,
    a.starts_at AS a_starts_at,
    a.ends_at_norm AS a_ends_at,
    b.starts_at AS b_starts_at,
    b.ends_at_norm AS b_ends_at
  FROM spans a
  JOIN spans b
    ON a.payment_method_id = b.payment_method_id
   AND (a.starts_at, a.ends_at_norm) <> (b.starts_at, b.ends_at_norm)
   AND a.starts_at <= b.ends_at_norm
   AND b.starts_at <= a.ends_at_norm
)
SELECT * FROM overlaps
ORDER BY payment_method_id, a_starts_at;

/* 3) Duplicate starts_at per key (may cause ambiguous ordering)
   Expectation: investigate any count > 1
*/
-- custom
SELECT customer_id, payment_method_id, starts_at, COUNT(*) AS cnt
FROM custom_pricing
GROUP BY 1,2,3
HAVING COUNT(*) > 1
ORDER BY 1,2,3;

-- default
SELECT payment_method_id, starts_at, COUNT(*) AS cnt
FROM default_pricing
GROUP BY 1,2
HAVING COUNT(*) > 1
ORDER BY 1,2;

/* 4) ends_at earlier than starts_at
   Expectation: 0 rows
*/
SELECT 'custom' AS src, *
FROM custom_pricing
WHERE ends_at IS NOT NULL AND ends_at < starts_at
UNION ALL
SELECT 'default' AS src, *
FROM default_pricing
WHERE ends_at IS NOT NULL AND ends_at < starts_at;

/* 5) Payments with NO matching pricing at payment time
   Expectation: 0 rows (business dependent)
*/
WITH cte_payments AS (
  SELECT payment_id, customer_id, payment_method_id, payment_date, total_volume
  FROM payments
),
custom_match AS (
  SELECT DISTINCT p.payment_id
  FROM cte_payments p
  JOIN custom_pricing cp
    ON cp.customer_id = p.customer_id
   AND cp.payment_method_id = p.payment_method_id
   AND p.payment_date >= cp.starts_at
   AND p.payment_date < COALESCE(cp.ends_at, DATE '9999-12-31')
),
default_match AS (
  SELECT DISTINCT p.payment_id
  FROM cte_payments p
  JOIN default_pricing dp
    ON dp.payment_method_id = p.payment_method_id
   AND p.payment_date >= dp.starts_at
   AND p.payment_date < COALESCE(dp.ends_at, DATE '9999-12-31')
)
SELECT p.*
FROM cte_payments p
LEFT JOIN custom_match  cm ON cm.payment_id = p.payment_id
LEFT JOIN default_match dm ON dm.payment_id = p.payment_id
WHERE cm.payment_id IS NULL AND dm.payment_id IS NULL;

/* 6) Payments with MULTIPLE matching rows BEFORE ranking (may be valid if both sources match)
   Expectation: max 2 (one custom + one default). Investigate >2.
*/
WITH cte_payments AS (
  SELECT payment_id, customer_id, payment_method_id, payment_date, total_volume FROM payments
),
custom_hits AS (
  SELECT p.payment_id, COUNT(*) AS custom_cnt
  FROM cte_payments p
  JOIN custom_pricing cp
    ON cp.customer_id = p.customer_id
   AND cp.payment_method_id = p.payment_method_id
   AND p.payment_date >= cp.starts_at
   AND p.payment_date < COALESCE(cp.ends_at, DATE '9999-12-31')
  GROUP BY 1
),
default_hits AS (
  SELECT p.payment_id, COUNT(*) AS default_cnt
  FROM cte_payments p
  JOIN default_pricing dp
    ON dp.payment_method_id = p.payment_method_id
   AND p.payment_date >= dp.starts_at
   AND p.payment_date < COALESCE(dp.ends_at, DATE '9999-12-31')
  GROUP BY 1
)
SELECT
  p.payment_id,
  COALESCE(ch.custom_cnt, 0)  AS custom_cnt,
  COALESCE(dh.default_cnt, 0) AS default_cnt,
  COALESCE(ch.custom_cnt, 0) + COALESCE(dh.default_cnt, 0) AS total_matches
FROM payments p
LEFT JOIN custom_hits  ch ON ch.payment_id = p.payment_id
LEFT JOIN default_hits dh ON dh.payment_id = p.payment_id
WHERE COALESCE(ch.custom_cnt, 0) + COALESCE(dh.default_cnt, 0) > 2
ORDER BY total_matches DESC;

/* 7) Sanity check on fee outputs: non-negative fees
   Expectation: depends on business rules; typically >= 0
*/
WITH out as (
  -- Replace with reference to the final output table/view if materialised
  SELECT * FROM (
    -- inline the logic or reference your final select
    -- see queries/02A_active_pricing.sql
    SELECT 1 AS dummy WHERE 1=0
  )
)
SELECT * FROM out
WHERE total_fixed_fee < 0 OR total_variable_fee < 0 OR total_fee < 0;

/* 8) Rate bounds (optional): expect rates within reasonable ranges
   Expectation: tune thresholds per business
*/
SELECT * FROM custom_pricing
WHERE fixed_rate < 0 OR variable_rate < 0
UNION ALL
SELECT * FROM default_pricing
WHERE fixed_rate < 0 OR variable_rate < 0;

/* 9) Optional: gaps detection if you expect continuous coverage in default_pricing
   Expectation: 0 gaps if defaults are meant to be continuous
*/
WITH ordered AS (
  SELECT
    payment_method_id,
    starts_at,
    COALESCE(ends_at, DATE '9999-12-31') AS ends_at_norm,
    LAG(COALESCE(ends_at, DATE '9999-12-31')) OVER (
      PARTITION BY payment_method_id
      ORDER BY starts_at
    ) AS prev_end
  FROM default_pricing
),
gaps AS (
  SELECT *
  FROM ordered
  WHERE prev_end IS NOT NULL
    AND DATEADD(day, 1, prev_end) < starts_at  -- adjust per engine (DATEADD/DATE_ADD/INTERVAL)
)
SELECT * FROM gaps
ORDER BY payment_method_id, starts_at;
