-- Minimal reference schema for pricing change detection
-- Adjust types to match your data warehouse (Snowflake, BigQuery, Redshift, Postgres, Databricks SQL)

CREATE TABLE custom_pricing (
    customer_id        VARCHAR,      -- customer identifier
    payment_method_id  VARCHAR,      -- payment method identifier
    starts_at          DATE,         -- pricing version effective start
    ends_at            DATE,         -- nullable: NULL means open-ended
    fixed_rate         DECIMAL(10,4), -- e.g. base fee per transaction
    variable_rate      DECIMAL(10,4)  -- e.g. percentage fee on volume
);

-- Note:
-- - This table assumes clean non-overlapping ranges.
-- - Add a surrogate key (e.g., pricing_id) if needed for deterministic ordering.
