-- queries/change_detection.sql
-- Purpose: Detect pricing updates over time for each (customer_id, payment_method_id)
-- Notes:
--   - Neutral, ANSI-ish SQL (works with Snowflake/BigQuery/Redshift/Postgres/Databricks with minor tweaks)
--   - Assumes well-formed, non-overlapping pricing ranges
--   - Add a surrogate key (e.g., pricing_id) for deterministic tiebreakers if needed

WITH pricing_timeline AS (
    SELECT
        customer_id,
        payment_method_id,
        starts_at,
        ends_at,
        fixed_rate  AS new_fixed_rate,
        variable_rate AS new_variable_rate,

        LAG(fixed_rate) OVER (
            PARTITION BY customer_id, payment_method_id
            ORDER BY starts_at
        ) AS old_fixed_rate,

        LAG(variable_rate) OVER (
            PARTITION BY customer_id, payment_method_id
            ORDER BY starts_at
        ) AS old_variable_rate
    FROM custom_pricing
)
SELECT
    customer_id,
    payment_method_id,
    starts_at AS pricing_updated_at,
    new_fixed_rate,
    new_variable_rate,
    old_fixed_rate,
    old_variable_rate
FROM pricing_timeline
WHERE old_fixed_rate IS NOT NULL
  AND (
        COALESCE(new_fixed_rate, 0) <> COALESCE(old_fixed_rate, 0)
     OR COALESCE(new_variable_rate, 0) <> COALESCE(old_variable_rate, 0)
  )
ORDER BY
    customer_id,
    payment_method_id,
    pricing_updated_at;
