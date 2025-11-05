# Onboarding Pricing — Active Selection per Payment

## Overview
Given a stream of **payments** and two pricing sources:
- **custom_pricing** (customer-specific rules over time)
- **default_pricing** (method-level fallback rules over time)

select the **applicable pricing row at payment time** for each payment and compute:
- `total_fixed_fee`
- `total_variable_fee`
- `total_fee = fixed + variable * volume`

When both sources match, **custom** has higher priority than **default**.

---

## Inputs (logical tables)

### `payments`
Minimal columns:
- `payment_id` (string)
- `customer_id` (string)
- `payment_method_id` (string)
- `payment_date` (date or timestamp)
- `total_volume` (numeric)

### `custom_pricing`
- `customer_id`
- `payment_method_id`
- `starts_at`, `ends_at` (nullable → open-ended)
- `fixed_rate`, `variable_rate`

### `default_pricing`
- `payment_method_id`
- `starts_at`, `ends_at` (nullable → open-ended)
- `fixed_rate`, `variable_rate`

> See `schema.sql` for minimal DDL.

---

## Output
One row per `payment_id` with the applied pricing and computed fees.

Columns:
- `payment_id`
- `total_volume`
- `total_fixed_fee`
- `total_variable_fee`
- `total_fee`

---

## Selection rules
1) A pricing row is **valid** if `payment_date` ∈ `[starts_at, ends_at)` where `ends_at` can be `NULL` (treated as far-future).  
2) If both **custom** and **default** match, **custom** wins (priority=1 vs 2).  
3) If multiple valid rows are found for the same source, choose the one with the **latest `starts_at`** (stable tiebreak).

---

## Engine notes
- ANSI-ish SQL; adjust date functions/types per engine.
- If `payment_date` is a timestamp, cast/normalize to the same type used in pricing ranges.
- Consider adding a **surrogate key** to pricing tables for deterministic ordering.

---

## Performance tips
- Partition/index pricing tables by `payment_method_id` (and `customer_id` for custom) + date ranges.
- Pre-filter candidate pricing via date predicates before windowing/ranking.
- If very large, consider **date-bucketed** pricing (e.g., by month) or maintain a **current/active** materialized table.

---

## Files in this project
- `context.md` — business rationale & usage
- `schema.sql` — minimal DDL for `payments`, `custom_pricing`, `default_pricing`
- `queries/02A_active_pricing.sql` — query joining payments to pricing with priority & ranking

---

## Status
✅ Query logic & docs (this README)  
⬜ `context.md`  
⬜ `schema.sql`  
⬜ `queries/active_pricing.sql` (neutralised from your final version)  
⬜ `qc_checks.sql`
