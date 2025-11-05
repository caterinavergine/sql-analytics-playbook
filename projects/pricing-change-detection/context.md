# Business Context & Logic — Pricing Change Detection

## Purpose
Track and understand **pricing evolution** for each customer and payment method over time.  
This model answers:
- When did pricing change?
- What specifically changed?
- What was the prior value?
- How often do price updates occur?

These insights support analytics, finance, and product workflows.

---

## Business Scenario
In many pricing systems, fee rules evolve based on:
- Negotiations with key customers
- Volume and performance tiers
- Risk policy adjustments
- Market changes or promotions
- Automated / rule‑based updates

Changes must be **audited, validated, and monitored** to ensure:
- Revenue and margin calculations remain correct
- Customers receive expected pricing
- Internal policies are followed
- Downstream models operate on correct historical inputs

---

## What qualifies as a “pricing change”
A new pricing version is created when at least one of the following changes:

| Attribute | Meaning |
|---|---|
| `fixed_rate` | Base fee per transaction |
| `variable_rate` | Percentage fee on value |

Other fields **may** change in a real system (e.g., minimum fees, currency, tiers), but this model isolates **core rate changes**.

---

## Key Concepts

### Timeline‑based logic
Each pricing row has a `starts_at` (and optionally an `ends_at`).  
Pricing is **versioned over time**.

### Window function logic
We use `LAG()` to compare each value to its prior version.  
If values differ → we emit that row as a “change event.”

### Null consistency
We use `COALESCE` to avoid detecting `NULL → NULL` as a change.

---

## What this file supports
This documentation enables users to:
- Understand the business behavior being modeled
- Interpret query results correctly
- Extend logic to additional attributes if needed
- Adapt to different data warehouse environments

---

## Example business insights
Questions you can answer using this model:

| Business Question | Example Output |
|---|---|
How often does pricing update per customer? | “Top 10 customers by annual price changes” |
Are pricing changes larger near renewal dates? | Change clustering around contract anniversary |
Are fee updates correlated with volume growth? | Correlation analysis: volume vs updated rates |
Which customers have unstable pricing? | Churn or risk signal |
Do changes lead to fraud or margin impact? | Outlier detection |

---

## Extensions / Next Models
This logic can feed into:
- Pricing audit dashboards
- Margin simulation and back‑testing
- Time‑aware ML features
- Governance alerts (unexpected frequency or size)
- Customer lifecycle analytics
