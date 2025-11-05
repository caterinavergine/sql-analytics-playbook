-- Purpose: Select the active pricing rule (custom vs default) for each payment and compute fees.
WITH cte_payments AS (
  SELECT
    p.payment_id,
    p.customer_id,
    p.payment_date,
    p.payment_method_id,
    p.total_volume
  FROM payments p
),
custom_pricing_org AS (
  SELECT
    pb.payment_id,
    pb.customer_id,
    pb.payment_date,
    pb.payment_method_id,
    pb.total_volume,
    cp.starts_at,
    cp.ends_at,
    cp.fixed_rate,
    cp.variable_rate,
    1  AS priority_id,
    'custom_pricing' AS priority_name
  FROM cte_payments pb
  JOIN custom_pricing cp
    ON cp.customer_id       = pb.customer_id
   AND cp.payment_method_id = pb.payment_method_id
   AND pb.payment_date >= cp.starts_at
   AND pb.payment_date < COALESCE(cp.ends_at, DATE '9999-12-31')
),
default_pricing_org AS (
  SELECT
    pb.payment_id,
    pb.customer_id,
    pb.payment_date,
    pb.payment_method_id,
    pb.total_volume,
    dp.starts_at,
    dp.ends_at,
    dp.fixed_rate,
    dp.variable_rate,
    2  AS priority_id,
    'default_pricing' AS priority_name
  FROM cte_payments pb
  JOIN default_pricing dp
    ON dp.payment_method_id = pb.payment_method_id
   AND pb.payment_date >= dp.starts_at
   AND pb.payment_date < COALESCE(dp.ends_at, DATE '9999-12-31')
),
ranked_pricing AS (
  SELECT
    pa.payment_id,
    pa.customer_id,
    pa.payment_date,
    pa.payment_method_id,
    pa.total_volume,
    pa.starts_at,
    pa.ends_at,
    pa.fixed_rate,
    pa.variable_rate,
    pa.priority_id,
    pa.priority_name,
    ROW_NUMBER() OVER (
      PARTITION BY pa.payment_id
      ORDER BY pa.priority_id ASC, pa.starts_at DESC
    ) AS rn
  FROM (   
  	SELECT * FROM custom_pricing_org
    UNION ALL
    SELECT * FROM default_pricing_org
  ) pa
),
filter_payments AS (
  SELECT
    p.payment_id,
    p.total_volume,
    rp.priority_name,
    COALESCE(rp.fixed_rate,    0)                                    AS total_fixed_fee,
    COALESCE(rp.variable_rate, 0) * p.total_volume                   AS total_variable_fee,
    COALESCE(rp.fixed_rate,    0) + (COALESCE(rp.variable_rate, 0) * p.total_volume) AS total_fee
  FROM cte_payments p
  LEFT JOIN ranked_pricing rp
    ON rp.payment_id = p.payment_id
   AND rp.rn = 1
)
SELECT
  payment_id,
  total_volume,
  total_fixed_fee,
  total_variable_fee,
  total_fee
FROM filter_payments
ORDER BY payment_id;
