-- qc_checks.sql
-- Quality checks for pricing_change_detection project
-- Run these queries to validate timeline integrity and input data hygiene.

/* 1) Overlapping ranges within the same (customer_id, payment_method_id)
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

/* 2) Duplicate starts_at per (customer_id, payment_method_id)
   Expectation: investigate any count > 1
*/
SELECT
  customer_id,
  payment_method_id,
  starts_at,
  COUNT(*) AS cnt
FROM custom_pricing
GROUP BY 1,2,3
HAVING COUNT(*) > 1
ORDER BY 1,2,3;

/* 3) Non-monotonic dates (ends_at < starts_at)
   Expectation: 0 rows
*/
SELECT *
FROM custom_pricing
WHERE ends_at IS NOT NULL
  AND ends_at < starts_at;

/* 4) Rows where neither fixed_rate nor variable_rate is set (both NULL)
   Expectation: business-dependent; often 0 rows
*/
SELECT *
FROM custom_pricing
WHERE fixed_rate IS NULL
  AND variable_rate IS NULL;

/* 5) Sanity: rows flagged as "no-op changes" (new == old) would be filtered out by the main query;
      this query confirms the COALESCE comparison logic is consistent.
   Expectation: these rows do not appear in change_detection output.
*/
WITH timeline AS (
  SELECT
    customer_id,
    payment_method_id,
    starts_at,
    fixed_rate,
    variable_rate,
    LAG(fixed_rate) OVER (PARTITION BY customer_id, payment_method_id ORDER BY starts_at) AS prev_fixed,
    LAG(variable_rate) OVER (PARTITION BY customer_id, payment_method_id ORDER BY starts_at) AS prev_variable
  FROM custom_pricing
)
SELECT *
FROM timeline
WHERE prev_fixed IS NOT NULL
  AND COALESCE(fixed_rate, 0) = COALESCE(prev_fixed, 0)
  AND COALESCE(variable_rate, 0) = COALESCE(prev_variable, 0)
ORDER BY customer_id, payment_method_id, starts_at;

/* 6) Optional: gaps detection (if you expect continuous coverage)
   Expectation: 0 gaps if timelines must be continuous
*/
WITH ordered AS (
  SELECT
    customer_id,
    payment_method_id,
    starts_at,
    COALESCE(ends_at, DATE '9999-12-31') AS ends_at_norm,
    LAG(COALESCE(ends_at, DATE '9999-12-31')) OVER (
      PARTITION BY customer_id, payment_method_id
      ORDER BY starts_at
    ) AS prev_end
  FROM custom_pricing
),
gaps AS (
  SELECT *
  FROM ordered
  WHERE prev_end IS NOT NULL
    AND DATEADD(day, 1, prev_end) < starts_at  -- adjust to your SQL dialect
)
SELECT * FROM gaps
ORDER BY customer_id, payment_method_id, starts_at;

/* Notes:
- DATEADD syntax may vary; use DATE_ADD or INTERVAL arithmetic per engine.
- If you don't require continuity, skip check (6).
*/
