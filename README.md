# E-Commerce Revenue Leakage Analysis — SQL-Driven Return Investigation

![SQL](https://img.shields.io/badge/SQL-Data%20Analysis-blue)
![Type](https://img.shields.io/badge/Project-Analytics%20Case%20Study-green)
![Status](https://img.shields.io/badge/Status-Completed-brightgreen)
![Domain](https://img.shields.io/badge/Domain-E--commerce-orange)

> **$389K in return-driven revenue loss identified** across a $5.87M e-commerce operation — with SQL-driven segmentation pinpointing exactly where to act first.

This analysis delivers end-to-end SQL investigation: data modeling and normalization, KPI design, customer risk segmentation, Pareto loss analysis, cohort behavior tracking, and business-oriented decision support — all translated into a Power BI dashboard.

## TL;DR

- Found **$389K recoverable revenue loss (5.52%)**
- Identified **35 customers abusing returns (91% rate)**
- Isolated **top 5 products driving disproportionate loss**
- Flagged **Electronics ($166K loss)** as highest-impact category
- Delivered **SQL + Power BI system for ongoing monitoring**

---

---

## Key Metrics

| Metric | Value |
|:---|---:|
| Gross Revenue | $5,865,293 |
| Return Loss | $388,756 |
| Net Revenue | $5,476,537 |
| Overall Return Rate | 5.52% |

---

## Key Findings

- **Electronics** generates the most revenue and the most return loss ($166K) — a high-value, high-risk trade-off that needs active management
- **Fashion** has the highest return rate at **8.05%**, likely driven by expectation mismatch rather than product defects
- **Top 5 loss products** account for a disproportionate share of total leakage — a clear Pareto pattern that makes SKU-level review the highest-leverage starting point
- **High-return customers** are mostly *not* the highest-value customers — risk and value must be monitored separately to avoid penalising your best buyers
- **35 customers** average a **91% return rate** — nearly everything they order comes back, suggesting wardrobing behavior or a systemic profile mismatch

---

## Dashboard Preview

![E-Commerce Revenue Leakage Dashboard](dashboard/dashboard_preview.png)

> Built in Power BI · Revenue overview · Customer risk segmentation · Product Pareto · Category breakdown

This dashboard enables:

- Real-time tracking of return-driven revenue loss
- Identification of high-risk customers and products
- Early detection of category-level return spikes
- Ongoing monitoring of recovery opportunities

---

## Business Recommendations

Based on SQL findings, the highest-leverage interventions are:

1. **Audit the top 5 loss products first** — a small SKU set drives a disproportionate share of the $389K leakage; quality, fulfillment, or description issues are the most likely culprits and the fastest path to measurable recovery

2. **Investigate Electronics for defect or expectation issues** — at $166K in return loss and a 7.3% return rate, this category is the single largest lever; even a 2% reduction in return rate recovers ~$40K annually

3. **Address Fashion's return rate through better product presentation** — 8.05% is the highest category rate and most likely reflects sizing information gaps or photography that misrepresents the product, not a quality problem

4. **Separate customer value from return risk in monitoring** — high-return customers are mostly not high-value customers; a blanket return policy change would penalise your best buyers to target a different group entirely

5. **Build a recurring return dashboard** — track return rate and return loss monthly by category and SKU so trends surface before they compound; Electronics at 7.3% already warrants a standing alert

---

## Analytical Approach

| Layer | Focus | Key Output |
|:---|:---|:---|
| Revenue Overview | Baseline health metrics | $389K leakage on $5.87M revenue |
| Customer Analysis | LTV vs. return risk separation | Risk segments: High / Moderate / Low |
| Product Analysis | SKU-level Pareto of losses | Top 5 products = outsized leakage share |
| Category Analysis | Return rate + loss by segment | Electronics = highest loss · Fashion = highest rate |
| Cohort Analysis | Repeat purchase behavior over time | ~12% reactivation rate at 12 months |

---

## SQL Highlights

This analysis uncovers revenue leakage, customer risk behavior, and product-level loss prioritization through advanced SQL — not simple aggregations. Each query below is written to answer a specific business question, not just to demonstrate technique.

---

### 1. Customer Return Risk Segmentation

Classifies customers based on return behavior to identify high-risk users contributing disproportionately to return volume.

**Why this query matters:** It deliberately separates return *frequency* from customer *value* — preventing a common and costly business mistake: penalizing high-value customers who occasionally return, while missing the small group of serial returners who drive the majority of loss. Without this separation, a blanket policy change would burden the wrong people.

```sql
SELECT
    customer_id,
    COUNT(o.order_id)                                          AS total_orders,
    COUNT(r.return_id)                                         AS total_returns,
    ROUND(COUNT(r.return_id) * 100.0 / COUNT(o.order_id), 2)  AS return_rate_pct,
    CASE
        WHEN COUNT(o.order_id) >= 3
             AND COUNT(r.return_id) * 100.0 / COUNT(o.order_id) > 30 THEN 'High Risk'
        WHEN COUNT(o.order_id) >= 3
             AND COUNT(r.return_id) * 100.0 / COUNT(o.order_id) > 10 THEN 'Moderate Risk'
        ELSE 'Low Risk'
    END AS risk_segment
FROM customers c
LEFT JOIN orders  o USING (customer_id)
LEFT JOIN returns r USING (order_id)
GROUP BY customer_id
ORDER BY return_rate_pct DESC;
```

---

### 2. Product Revenue Leakage Ranking

Ranks every product by total return loss using a CTE and `RANK()` window function.

```sql
WITH product_revenue AS (
    SELECT
        p.product_id,
        p.category,
        SUM(o.order_value)                                              AS gross_revenue,
        SUM(CASE WHEN r.return_id IS NOT NULL
                 THEN o.order_value ELSE 0 END)                         AS return_loss,
        COUNT(r.return_id)                                              AS return_count
    FROM products p
    JOIN orders   o USING (product_id)
    LEFT JOIN returns r USING (order_id)
    GROUP BY p.product_id, p.category
)
SELECT
    product_id,
    category,
    gross_revenue,
    return_loss,
    ROUND(return_loss * 100.0 / NULLIF(gross_revenue, 0), 2)            AS loss_rate_pct,
    RANK() OVER (ORDER BY return_loss DESC)                             AS loss_rank
FROM product_revenue
ORDER BY return_loss DESC;
```

---

### 3. Pareto Loss Analysis — Cumulative Distribution

Identifies the small subset of products responsible for the majority of return-driven revenue loss using cumulative window functions. Allows the business to prioritize high-impact products rather than treating all returns equally.

```sql
WITH product_loss AS (
    SELECT
        p.product_name,
        SUM(o.total_amount) AS total_loss
    FROM returns r
    JOIN orders   o ON r.order_id  = o.order_id
    JOIN products p ON o.product_id = p.product_id
    GROUP BY p.product_name
),
ranked AS (
    SELECT
        product_name,
        total_loss,
        SUM(total_loss) OVER ()                        AS total_loss_all,
        SUM(total_loss) OVER (ORDER BY total_loss DESC) AS cumulative_loss
    FROM product_loss
)
SELECT
    product_name,
    total_loss,
    cumulative_loss,
    ROUND(cumulative_loss * 100.0 / total_loss_all, 2)  AS cumulative_pct
FROM ranked
ORDER BY total_loss DESC;
```

> Full SQL scripts → [`/sql`](sql/)

---

## Customer Risk Segmentation

Customers were classified into four risk tiers based on return rate and order volume:

| Segment | Customers | Avg Return Rate | Business Implication |
|:---|---:|---:|:---|
| High Risk | 35 | 91.2% | Likely systematic — warrants individual review |
| Moderate Risk | 741 | 33.6% | Repeat returners — monitor for policy intervention |
| Low Risk | 940 | 16.3% | Occasional returners — normal behavior |
| No Returns | 6,187 | 0% | 78% of the customer base — problem is concentrated |

**Key insight:** The High Risk segment is only 35 customers but averages a 91% return rate — meaning nearly everything they order comes back. This almost certainly reflects wardrobing behavior or a systemic expectation mismatch. These 35 accounts warrant individual review before any broad policy change.

**Why this matters for policy:** 78% of customers have never made a return. A blanket policy tightening would burden the vast majority of well-behaved customers to address the behavior of less than 1% of the base.

---

## Cohort Analysis — Repeat Purchase Behavior

Customers grouped by first purchase month and tracked for return activity over time.

**Data context:** The dataset contains orders from Oct–Dec 2023 and Oct–Dec 2024 only. Due to the absence of months 2–9, this analysis focuses specifically on long-term reactivation rather than continuous retention — isolating annual repeat behavior as a distinct signal.

| Cohort | Month 0 Customers | Month 1 Return Rate | ~12-Month Return Rate |
|:---|---:|---:|---:|
| Oct 2023 | 961 | 11.2% | 12.3% |
| Nov 2023 | 795 | 12.1% | 13.7% |
| Dec 2023 | 795 | — | 12.6% |
| Oct 2024 | 700 | 11.7% | — |

**Key finding:** ~11–13% of customers reactivate ~12 months after their first purchase, suggesting a meaningful annual repeat-buyer segment. Short-term month-1 return rates (~12%) are consistent across cohorts.

**Scope note:** Without data for months 2–9, mid-term retention cannot be assessed. This analysis intentionally scopes to long-term reactivation and short-term month-1 behavior — two signals the data can support reliably.

> Full cohort analysis → [`sql/12_cohort_analysis.sql`](sql/12_cohort_analysis.sql)

---

## Data Integrity and Validation

All analytical outputs are supported by validation steps to ensure accuracy and consistency:

- Row count reconciliation across data layers
- Duplicate detection in transactional records
- Revenue consistency checks before and after transformation
- Referential integrity validation between orders and returns
- Null and missing value checks in key fields

### Example: Revenue Reconciliation Check

```sql
-- Total revenue before cleaning
SELECT SUM(order_value) FROM staging_ecommerce;

-- Total revenue after transformation
SELECT SUM(total_amount) FROM orders;
```

Matching totals confirm that normalization and transformation steps preserve financial accuracy with no artificial inflation or loss.

> All validation queries → [`sql/07_data_validation.sql`](sql/07_data_validation.sql)

---

### Join Pitfall Demonstration

A naive join between orders and returns can inflate revenue figures due to row duplication. This project demonstrates both the incorrect aggregation approach and the corrected version using deduplication.

> Full details → [`sql/09_join_pitfall_demo.sql`](sql/09_join_pitfall_demo.sql)

---

## Architecture Overview

```
┌──────────────────────────────────────────────┐
│  SOURCE                                      │
│  Kaggle CSV — raw, denormalized, wide file   │
└─────────────────────┬────────────────────────┘
                      │
                      ▼
┌──────────────────────────────────────────────┐
│  STAGING                                     │
│  staging_ecommerce — loaded as-is            │
│  Preserves source integrity                  │
└─────────────────────┬────────────────────────┘
                      │  SQL ETL (02_data_loading.sql)
                      ▼
┌──────────────────────────────────────────────┐
│  NORMALIZED SCHEMA                           │
│                                              │
│  customers ──┐                               │
│              ├──► orders ──► returns         │
│  products ───┘                               │
│                                              │
│  FK constraints · no redundancy             │
└─────────────────────┬────────────────────────┘
                      │
                      ▼
┌──────────────────────────────────────────────┐
│  ANALYTICAL LAYER                            │
│  CTEs · Window functions · Aggregations      │
│  03 revenue · 04 customer · 05 product       │
│  06 category                                 │
└─────────────────────┬────────────────────────┘
                      │
                      ▼
┌──────────────────────────────────────────────┐
│  POWER BI DASHBOARD                          │
│  Revenue · Customer · Product · Category     │
└──────────────────────────────────────────────┘
```

> Full details → [`docs/architecture.md`](docs/architecture.md)

---

## Project Structure

```
ecommerce-revenue-leakage/
│
├── dashboard/
│   ├── dashboard_preview.png       # Static preview image
│   └── e-comm_dashboard.pbix       # Power BI dashboard file
│
├── data/
│   ├── raw/                        # Original Kaggle dataset (unmodified)
│   └── cleaned/                    # Normalized CSVs after ETL
│
├── docs/
│   ├── ERD.md                      # Entity relationship diagram + rationale
│   ├── ERD.png                     # Visual ERD (dbdiagram.io)
│   ├── architecture.md             # Pipeline architecture overview
│   ├── architecture_ETL.png        # ETL flow diagram
│   └── data_modeling.md            # Normalization decisions + SQL examples
│
├── sql/
│   ├── 01_schema.sql               # Table creation + foreign key constraints
│   ├── 02_data_loading.sql         # Staging ingest + ETL transforms
│   ├── 03_revenue_analysis.sql     # KPIs: gross revenue, return loss, net revenue
│   ├── 04_customer_analysis.sql    # LTV ranking + risk segmentation
│   ├── 05_product_analysis.sql     # Pareto analysis + loss ranking
│   ├── 06_category_analysis.sql    # Category return rates + leakage
│   ├── 07_data_validation.sql      # Row counts, duplicates, null checks
│   ├── 08_pareto_analysis.sql      # Cumulative loss distribution
│   ├── 09_join_pitfall_demo.sql    # Naive vs. corrected join approach
│   ├── 10_time_analysis.sql        # Time-based trends
│   ├── 11_customer_behavior_analysis.sql  # Behavioral patterns
│   └── 12_cohort_analysis.sql      # Repeat purchase cohort tracking
│
├── README.md
└── license
```

---

## Why This Project Stands Out

- **Goes beyond basic SQL**: uses window functions, CTEs, segmentation logic, cohort tracking, and Pareto analysis rather than flat aggregations
- **Focuses on revenue impact, not just metrics**: every query ties back to a dollar figure or a business action
- **Translates analysis into decisions**: findings are framed as prioritized interventions, not just observations
- **Includes data modeling and validation**: schema normalization, FK constraints, ETL reconciliation, and join pitfall demonstration show end-to-end rigor, not just querying

---

## How to Run This Project

1. Create a new database
2. Run `sql/01_schema.sql` — creates tables and foreign key constraints
3. Run `sql/02_data_loading.sql` — loads and transforms staging data
4. Run analysis scripts in order:
   - `03_revenue_analysis.sql`
   - `04_customer_analysis.sql`
   - `05_product_analysis.sql`
   - `06_category_analysis.sql`
   - through `12_cohort_analysis.sql`

---

## Recommended Next Steps

> **If you read nothing else:** 35 customers average a 91% return rate, Electronics alone accounts for $166K in loss, and we still don't know *why* — because return reasons aren't captured. That's the single highest-leverage gap in this dataset.

After delivering these findings, my next three priorities would be:

- **Add a `return_reason` field** — right now we know *where* leakage is concentrated but not *why*. One column unlocks root cause analysis and turns this from a measurement project into an actionable one.
- **Run a cohort analysis on high-return customers** — are they new customers with misaligned expectations, or long-term customers with quality concerns? The answer changes the intervention entirely.
- **Set return rate alert thresholds in the dashboard** — Electronics at 7.3% is already elevated; a trigger at 8% gives the team a leading indicator before losses compound, shifting the response from reactive to proactive.

---

## Dataset

[Kaggle: E-Commerce Dataset — Orders & Returns](https://www.kaggle.com/datasets/angellawl/e-commerce-dataset-order-and-return)

## Tools

![SQL](https://img.shields.io/badge/SQL-SQLite%20%2F%20PostgreSQL-blue?style=flat-square)
![Power BI](https://img.shields.io/badge/Power%20BI-Dashboard-yellow?style=flat-square)
![GitHub](https://img.shields.io/badge/GitHub-Repository-black?style=flat-square)
![Mermaid](https://img.shields.io/badge/Mermaid-Diagramming-FF69B4?style=flat-square)
![dbdiagram.io](https://img.shields.io/badge/dbdiagram.io-DB%20Design-orange?style=flat-square)

## Related Docs

| Document | Description |
|:---|:---|
| [`docs/data_modeling.md`](docs/data_modeling.md) | Normalization decisions, ETL transforms, schema validation |
| [`docs/ERD.md`](docs/ERD.md) | Entity relationship diagram with design rationale |
| [`docs/architecture.md`](docs/architecture.md) | Full pipeline architecture breakdown |
