# Business Context & Logic — Onboarding Pricing (Active Selection per Payment)

## Purpose
Determine the **correct pricing rule** (custom vs default) to apply to each payment at the **exact moment the payment occurs**, and calculate the resulting fees.

This supports:
- Accurate **revenue & margin calculation**
- **Billing** and financial reconciliation
- **Customer onboarding pricing flows**
- **Pricing governance** and transparency
- **Historical re-rating** for analytics or corrections

---

## Business Scenario
A platform supports multiple payment methods, each with pricing that may vary over time.

Two pricing sources exist:

| Source | Scope | Typical use case |
|---|---|---|
Custom pricing | Specific to a customer | Negotiated commercial terms |
Default pricing | Per payment method | Standard fee schedule |

When a payment occurs, we must select **one and only one** pricing rule.  
If both match, **custom wins**.

This logic mimics real-world onboarding and pricing engines.

---

## What “Active Pricing” Means
A pricing rule is **active** for a payment if:

```
payment_date >= starts_at
AND payment_date < COALESCE(ends_at, far_future_date)
```

This ensures open-ended pricing rules (`ends_at IS NULL`) are always considered valid until explicitly closed.

---

## Priority Rules
If multiple rules match a payment:

| Rule | Priority |
|---|---|
Custom pricing | Higher (1) |
Default pricing | Lower (2) |

If multiple rules exist within one source, choose the **latest effective one** (`starts_at` DESC).

This ensures correctness even with pricing updates over time.

---

## Example
If:
- Customer A has a custom fixed fee from Jan 1 → Feb 1
- Default fee applies always

Then a payment on Jan 15 uses **custom**.  
A payment on Feb 15 uses **default**, unless a new custom rule starts.

---

## Output Metrics
For each payment, calculate:

| Metric | Definition |
|---|---|
`total_fixed_fee` | Selected `fixed_rate` |
`total_variable_fee` | `variable_rate * total_volume` |
`total_fee` | `fixed + variable * volume` |

These feed:
- Invoicing and financial ledgers
- Product analytics
- Revenue reporting
- Experimentation on pricing strategy

---

## Extensions / Next Models
This logic can be extended to support:

- Tiered pricing by volume
- Minimum fees and caps
- Multi-currency and FX
- Partner‑specific overrides
- Real-time pricing API integration
- Materialized **current active pricing table**

---

## Best Practice Notes
- Maintain pricing timelines with **no overlaps**
- Use surrogate keys for stable ordering if needed
- If pricing changes frequently, consider caching or incremental models
- Validate pricing data with QC rules (overlaps, gaps, duplicates)
