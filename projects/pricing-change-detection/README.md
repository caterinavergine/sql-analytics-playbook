# Pricing Change Detection

Identify **when pricing changes** over time for each `(customer_id, payment_method_id)` by comparing each row with the **previous valid row** using SQL window functions (`LAG`).

---

## Why this matters
In most onboarding/commerce setups, pricing evolves. Auditing **what changed, when, and for whom** is essential for:
- Finance & RevOps (fee evolution, margin impact)
- Governance & Compliance (who/when/why changes)
- Experimentation (effect of pricing updates on conversion)
- Feature stores (creating change-based features)

---

## Inputs (logical tables)
### `custom_pricing`
Minimal columns (extend as needed):
- `customer_id` (string)
- `payment_method_id` (string)
- `starts_at` (date)
- `ends_at` (date, nullable — open-ended)
- `fixed_rate` (numeric/decimal)
- `variable_rate` (numeric/decimal)

> See `schema.sql` for minimal DDL.

---

## Output (logical view)
One row **per change event**, including previous and new values:

| Column | Description |
|---|---|
| `customer_id` | Customer key |
| `payment_method_id` | Payment method key |
| `pricing_updated_at` | Timestamp/date when the new row becomes effective (`starts_at` of the new row) |
| `new_fixed_rate`, `new_variable_rate` | New values |
| `old_fixed_rate`, `old_variable_rate` | Previous values |

Only rows where at least **one** rate changed are returned.

---

## Core Logic (Query 2A)
- Partition by `(customer_id, payment_method_id)`
- Order by `starts_at` (and a stable tiebreaker if available)
- Use `LAG()` to bring previous values into the current row
- Emit only rows where current vs previous differ

> The neutralised SQL lives in `queries/change_detection.sql` (no vendor-specific references).

---

## Edge cases & assumptions
- **Overlapping ranges**: this query assumes a well-formed timeline (no overlaps). If overlaps exist, pre-normalise or add deterministic ranking (e.g., latest `starts_at`, higher priority row id).
- **Duplicate `starts_at`**: add a stable tie-breaker (`pricing_id` / surrogate key) in the `ORDER BY` of the window.
- **NULL handling**: unchanged `NULL` vs `NULL` should *not* appear as a change; `COALESCE` normalises comparisons.
- **Granularity**: each row represents a pricing rule version; ensure `starts_at` reflects activation time consistently.

---

## Engine compatibility
ANSI-ish SQL. Works on Snowflake, BigQuery, Redshift, Postgres, Databricks SQL with minor adjustments.
- Replace date literals/types to match your engine if needed.
- For timestamps, use `::timestamp` or `CAST` explicitly if your engine is strict.

---

## Parameterisation (optional)
Introduce an `as_of_date` only if you want to detect changes **up to** a specific time window. This project focuses on *point-in-time change events* based on the timeline order.

---

## Typical uses
- **Pricing audit trail** dashboard
- **Backfill** fee changes impacting historical orders
- **Alerts** on abnormal changes (e.g., spikes in variable rate)
- **Features** for ML models: “days since last price change”, “# of changes last 90 days”, etc.

---

## Next files in this project
- `schema.sql` — minimal DDL to reproduce the tables
- `queries/change_detection.sql` — the SQL for change detection
- `qc_checks.sql` (optional) — recommended quality checks


