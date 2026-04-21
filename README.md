# E-Commerce Revenue Leakage Analysis — SQL-Driven Return Investigation

![Impact](https://img.shields.io/badge/Impact-$389K_Revenue_Loss_Analyzed-blue)
![Project](https://img.shields.io/badge/Type-Analytics_Case_Study-green)
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

This project focuses on identifying revenue leakage, customer behavior patterns, and product-level loss concentration using analytical SQL.

---

### 1. Customer Return Risk Segmentation

Identifies customers based on return behavior to detect abnormal return patterns.

**Why this matters:**  
Most return systems fail by treating all customers the same. This hides the real problem, a small group of customers driving disproportionate return activity, while high-value customers are incorrectly penalized.

This segmentation separates:
- behavioral risk (return frequency)
- from business value (order behavior)

```sql
WITH customer_orders AS (
    SELECT 
        customer_id,
        COUNT(order_id) AS total_orders,
        SUM(total_amount) AS total_revenue,
        SUM(CASE WHEN returned = 'Yes' THEN 1 ELSE 0 END) AS total_returns,
        SUM(CASE WHEN returned = 'Yes' THEN total_amount ELSE 0 END) AS return_loss
    FROM staging_ecommerce
    GROUP BY customer_id
),

base AS (
    SELECT 
        *,
        CAST(total_returns AS FLOAT) / NULLIF(total_orders, 0) AS return_rate
    FROM customer_orders
),

filtered AS (
    SELECT *
    FROM base
    WHERE total_orders >= 3
),

scored AS (
    SELECT
        *,
        
        -- normalize loss impact vs peers
        NTILE(4) OVER (ORDER BY return_loss DESC) AS loss_quartile
    FROM filtered
)

SELECT 
    customer_id,
    total_orders,
    total_returns,
    ROUND(total_revenue, 2) AS total_revenue,
    ROUND(return_loss, 2) AS return_loss,
    ROUND(return_rate, 3) AS return_rate,

    CASE
        -- extreme behavioral + financial risk
        WHEN return_rate >= 0.6 AND loss_quartile = 1 THEN 'High Risk'

        -- moderate behavioral + moderate loss
        WHEN return_rate >= 0.3 AND loss_quartile <= 2 THEN 'Moderate Risk'

        -- low behavior OR low financial impact
        ELSE 'Low Risk'
    END AS risk_segment

FROM scored
ORDER BY return_loss DESC;
```

---

### 2. Product Revenue Leakage Ranking

Ranks products by total financial loss caused by returns using a CTE and `RANK()` window function.

```sql
WITH product_base AS (
    SELECT
        p.product_id,
        p.category,

        COUNT(o.order_id) AS total_orders,
        SUM(o.total_amount) AS gross_revenue,

        SUM(CASE WHEN r.order_id IS NOT NULL THEN 1 ELSE 0 END) AS return_orders,
        SUM(CASE WHEN r.order_id IS NOT NULL THEN o.total_amount ELSE 0 END) AS return_loss

    FROM products p
    JOIN orders o 
        ON p.product_id = o.product_id

    LEFT JOIN returns r 
        ON o.order_id = r.order_id

    GROUP BY p.product_id, p.category
),

filtered AS (
    SELECT *
    FROM product_base
    WHERE total_orders >= 3   -- 🔥 KEY FIX: remove noise / single-order products
),

scored AS (
    SELECT
        *,
        ROUND(return_loss * 1.0 / NULLIF(gross_revenue, 0), 4) AS loss_rate,
        ROUND(return_orders * 1.0 / NULLIF(total_orders, 0), 4) AS return_rate
    FROM filtered
)

SELECT
    product_id,
    category,
    total_orders,
    ROUND(gross_revenue, 2) AS gross_revenue,
    ROUND(return_loss, 2) AS return_loss,
    loss_rate,
    return_rate,

    RANK() OVER (ORDER BY return_loss DESC) AS loss_rank

FROM scored
ORDER BY return_loss DESC;
```

---

### 3. Pareto Loss Analysis — Cumulative Distribution

Identifies whether a small subset of products is responsible for most return-related losses. Hence, allowing the business to prioritize high-impact products rather than treating all returns equally.

```sql
WITH product_loss AS (
    SELECT
        p.product_id,
        SUM(CASE WHEN r.order_id IS NOT NULL THEN o.total_amount ELSE 0 END) AS total_loss
    FROM products p
    JOIN orders o 
        ON p.product_id = o.product_id
    LEFT JOIN returns r 
        ON o.order_id = r.order_id
    GROUP BY p.product_id
),

ranked AS (
    SELECT
        product_id,
        total_loss,
        SUM(total_loss) OVER () AS total_loss_all,
        SUM(total_loss) OVER (ORDER BY total_loss DESC) AS cumulative_loss
    FROM product_loss
)

SELECT
    product_id,
    total_loss,
    cumulative_loss,
    ROUND(cumulative_loss * 100.0 / NULLIF(total_loss_all, 0), 2) AS cumulative_pct
FROM ranked
ORDER BY total_loss DESC;
```

> Full SQL scripts → [`/sql`](sql/)

---

## Customer Risk Segmentation

Customers were classified into four risk tiers based on return rate and order volume (minimum order threshold applied to reduce noise from low-activity customers):

| Segment | Customers | Avg Return Rate | Business Implication |
|:---|---:|---:|:---|
| High Risk | 17 | 87.8% | Extreme return behavior — likely systematic issue or severe expectation mismatch |
| Moderate Risk | 1,006 | ~33–40% | Repeat returners — requires monitoring and deeper behavioral analysis |
| Low Risk | 7,982 | ~12–20% | Normal customer behavior — expected return patterns |
| No Returns | 6,187 | 0% | Majority of customer base — stable segment with no return activity |

**Key insight:**  
The previously assumed “small group of extreme abusers” is **significantly smaller and less dominant than initially thought once filtering and minimum order constraints are applied**. The High Risk group exists, but it is not the main driver of overall return volume.

**What this actually means:**  
Returns are not concentrated in a single abusive segment. Instead, they are **distributed across a broader moderate-risk population**, which reduces the effectiveness of targeting only extreme customers.

**Why this matters for policy:**  
A blanket policy change targeting all returners would be inefficient. Since **the majority of customers (7,982 + 6,187) are low or no-return users**, aggressive restrictions would negatively affect good customers while only marginally impacting total return loss.

---

## Cohort Analysis — Repeat Purchase Behavior

Customers grouped by first purchase month and tracked for return behavior over time.

**Data context:**  
The dataset contains orders from Oct–Dec 2023 and Oct–Dec 2024 only. Because months 2–9 are missing, this analysis cannot measure continuous retention curves. It is limited to short-term return behavior and long-term reactivation signals.

| Cohort | Month 0 Customers | Month 1 Return Rate | ~12-Month Return Rate |
|:---|---:|---:|---:|
| Oct 2023 | 961 | 11.2% | 12.3% |
| Nov 2023 | 795 | 12.1% | 13.7% |
| Dec 2023 | 795 | — | 12.6% |
| Oct 2024 | 700 | 11.7% | — |

**Key finding:**  
Return/reactivation behavior is remarkably stable across cohorts, staying in the ~11–13% range. This suggests that repeat engagement is consistent over time rather than being driven by specific cohort anomalies.

**What this actually means:**  
- There is **no strong cohort decay pattern visible in the available data**
- Repeat behavior appears **structurally stable, not time-dependent**
- The signal is more likely driven by **product/category experience rather than customer lifecycle effects**

**Scope limitation (important):**  
Because intermediate months (2–9) are missing, it is impossible to evaluate:
- true retention curves
- churn timing
- mid-term engagement drop-off

This means the analysis is **directional only**, not a full lifecycle model.

**Conclusion:**  
The dataset supports only a simplified interpretation: customer repeat behavior is stable, but the absence of continuous time coverage limits deeper lifecycle conclusions.

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
