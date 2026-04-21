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

This project focuses on identifying revenue leakage, customer return behavior, and product-level loss concentration using analytical SQL.

### 1. Customer Return Risk Segmentation

This analysis separates **behavioral risk** from **financial impact** so customers are not treated as a single return group.

**Why this matters:**
Most return systems fail because they apply blanket rules across the customer base. That can penalize loyal customers while missing the groups actually creating meaningful return-related loss.

**SQL Script**

```sql
WITH customer_orders AS (
    SELECT
        customer_id,
        COUNT(order_id) AS total_orders,
        ROUND(SUM(total_amount), 2) AS total_revenue,
        SUM(CASE WHEN returned = 'Yes' THEN 1 ELSE 0 END) AS total_returns,
        ROUND(SUM(CASE WHEN returned = 'Yes' THEN total_amount ELSE 0 END), 2) AS return_loss
    FROM staging_ecommerce
    GROUP BY customer_id
),

base AS (
    SELECT
        customer_id,
        total_orders,
        total_revenue,
        total_returns,
        return_loss,
        ROUND(total_returns * 1.0 / NULLIF(total_orders, 0), 4) AS return_rate
    FROM customer_orders
),

filtered AS (
    SELECT *
    FROM base
    WHERE total_orders >= 3
),

ranked AS (
    SELECT
        *,
        NTILE(5) OVER (ORDER BY return_loss DESC) AS loss_quintile
    FROM filtered
)

SELECT
    customer_id,
    total_orders,
    total_returns,
    total_revenue,
    return_loss,
    return_rate,
    CASE
        WHEN total_returns = 0 THEN 'No Returns'
        WHEN return_rate >= 0.50 THEN 'High Risk'
        WHEN return_rate >= 0.20 THEN 'Moderate Risk'
        ELSE 'Low Risk'
    END AS behavior_segment,
    CASE
        WHEN total_returns = 0 THEN 'No Impact'
        WHEN loss_quintile = 1 THEN 'High Impact'
        ELSE 'Low Impact'
    END AS impact_segment
FROM ranked
WHERE total_returns > 0

UNION ALL

SELECT
    customer_id,
    total_orders,
    total_returns,
    total_revenue,
    return_loss,
    return_rate,
    'No Returns' AS behavior_segment,
    'No Impact' AS impact_segment
FROM base
WHERE total_returns = 0

ORDER BY return_loss DESC, return_rate DESC;
```
### Key Insight

The high-risk group exists, but it is much smaller than expected. Return activity is not driven only by a tiny abusive segment. A broader moderate-risk population contributes meaningful return volume, which makes blanket restriction policies less effective.

---

### 2. Product Revenue Leakage Ranking

This analysis ranks products by return-related financial loss using product-level revenue, return volume, and leakage metrics.

Why this matters:
A product may have a high return rate without being the biggest business problem. Looking at both return behavior and financial loss helps identify where intervention matters most.

```sql
WITH product_leakage AS (
    SELECT
        p.product_id,
        p.category,
        COUNT(o.order_id) AS total_orders,
        ROUND(SUM(o.total_amount), 2) AS gross_revenue,
        COUNT(r.order_id) AS return_orders,
        ROUND(
            COALESCE(SUM(CASE WHEN r.order_id IS NOT NULL THEN o.total_amount END), 0),
            2
        ) AS return_loss
    FROM products p
    JOIN orders o
        ON p.product_id = o.product_id
    LEFT JOIN returns r
        ON o.order_id = r.order_id
    GROUP BY p.product_id, p.category
),
filtered AS (
    SELECT *
    FROM product_leakage
    WHERE total_orders >= 3
)
SELECT
    product_id,
    category,
    total_orders,
    gross_revenue,
    return_orders,
    return_loss,
    ROUND(return_loss * 1.0 / NULLIF(gross_revenue, 0), 4) AS loss_rate,
    RANK() OVER (ORDER BY return_loss DESC) AS loss_rank
FROM filtered
ORDER BY return_loss DESC
LIMIT 10;
```
### Key insight:
Several products show extremely high loss_rate, meaning return-related loss consumes a large share of product revenue. That points to likely issues in product quality, fulfillment accuracy, or expectation mismatch.

---

### 3. Pareto Loss Analysis — Cumulative Distribution

This analysis tests whether a small subset of products is responsible for most return-related losses.

Why this matters:
If return loss is highly concentrated, the business can focus on a small number of products. If it is spread more broadly, recovery efforts need to be wider.

```sql
WITH product_loss AS (
    SELECT
        p.product_id,
        p.category,
        ROUND(
            COALESCE(SUM(CASE WHEN r.order_id IS NOT NULL THEN o.total_amount END), 0),
            2
        ) AS total_loss
    FROM products p
    JOIN orders o
        ON p.product_id = o.product_id
    LEFT JOIN returns r
        ON o.order_id = r.order_id
    GROUP BY p.product_id, p.category
),
ranked AS (
    SELECT
        product_id,
        category,
        total_loss,
        SUM(total_loss) OVER () AS total_loss_all,
        SUM(total_loss) OVER (ORDER BY total_loss DESC, product_id) AS cumulative_loss
    FROM product_loss
    WHERE total_loss > 0
)
SELECT
    product_id,
    category,
    total_loss,
    cumulative_loss,
    ROUND(cumulative_loss * 100.0 / NULLIF(total_loss_all, 0), 2) AS cumulative_pct
FROM ranked
ORDER BY total_loss DESC, product_id;
```
### Key insight:
Loss is concentrated in top products, but not strongly enough to support a simple 80/20 story. The distribution is broader than expected.

### 4. Cohort Analysis: Repeat Purchase Behavior

Customers are grouped by first purchase month and tracked by later activity month to measure repeat purchase behavior over time.

Why this matters:
Cohort analysis helps test whether repeat behavior is stable or whether customer engagement declines over time.

```sql
WITH first_purchase AS (
    SELECT
        customer_id,
        MIN(strftime('%Y-%m-01', order_date)) AS cohort_month
    FROM orders
    GROUP BY customer_id
),
customer_activity AS (
    SELECT
        o.customer_id,
        strftime('%Y-%m-01', o.order_date) AS activity_month,
        f.cohort_month
    FROM orders o
    JOIN first_purchase f
        ON o.customer_id = f.customer_id
),
cohort_size AS (
    SELECT
        cohort_month,
        COUNT(DISTINCT customer_id) AS cohort_customers
    FROM first_purchase
    GROUP BY cohort_month
),
cohort_data AS (
    SELECT
        ca.cohort_month,
        ca.activity_month,
        (
            (CAST(strftime('%Y', ca.activity_month) AS INTEGER) - CAST(strftime('%Y', ca.cohort_month) AS INTEGER)) * 12
        ) +
        (
            CAST(strftime('%m', ca.activity_month) AS INTEGER) - CAST(strftime('%m', ca.cohort_month) AS INTEGER)
        ) AS months_since_first_order,
        COUNT(DISTINCT ca.customer_id) AS active_customers
    FROM customer_activity ca
    GROUP BY ca.cohort_month, ca.activity_month
)
SELECT
    cd.cohort_month,
    cs.cohort_customers,
    cd.activity_month,
    cd.months_since_first_order,
    cd.active_customers,
    ROUND(cd.active_customers * 100.0 / NULLIF(cs.cohort_customers, 0), 2) AS retention_rate
FROM cohort_data cd
JOIN cohort_size cs
    ON cd.cohort_month = cs.cohort_month
ORDER BY cd.cohort_month, cd.months_since_first_order;
```
### Important limitation:
The dataset does not contain a full continuous monthly timeline, so this analysis is directional only and should not be interpreted as a complete lifecycle retention model.

### Key insight:
Observed repeat behavior appears relatively stable across cohorts, suggesting product or experience factors may matter more than lifecycle timing in this dataset.

> Full SQL scripts → [`/sql`](sql/)

---

### Customer Risk Segmentation and Financial Impact

Customers were segmented by **return behavior** using return rate and a minimum order threshold to reduce noise from low-activity accounts. To make the analysis business-relevant, each segment was also evaluated by its financial contribution to return-related loss.

| Behavior Segment | Customers | Avg Return Rate (%) | Total Revenue | Total Return Loss | Share of Total Return Loss (%) | Avg Loss per Customer |
|------------------|-----------|---------------------|---------------|-------------------|-------------------------------|-----------------------|
| High Risk        | 42        | 53.41               | 27,610.66     | 19,317.39         | 5.35                          | 459.94                |
| Moderate Risk    | 903       | 26.16               | 724,253.83    | 206,387.22        | 57.20                         | 228.56                |
| Low Risk         | 628       | 14.44               | 771,076.21    | 135,131.30        | 37.45                         | 215.18                |
| No Returns       | 6,187     | 0.00                | 4,292,312.10  | 0.00              | 0.00                          | 0.00                  |

**Key insight:**  
The most extreme returners are not the main financial problem. Although the High Risk segment shows the highest average return behavior, it contributes only **5.35%** of total return-related loss. The larger **Moderate Risk** segment is the real driver of leakage, accounting for **57.2%** of total return loss.

**What this means:**  
Return-related revenue leakage is not concentrated in a tiny group of abusive customers. Instead, the larger Moderate Risk population creates the biggest business impact through scale. This suggests the problem is broader than abuse alone and may also reflect product mismatch, fulfillment issues, or expectation gaps.

**Why this matters for policy:**  
A blanket return restriction policy would likely be inefficient. The business would risk creating friction for healthy customers while failing to meaningfully reduce the main source of financial loss. A better strategy is to monitor extreme returners, but prioritize investigation into the broader Moderate Risk segment where most leakage occurs.


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

```text
ecommerce-revenue-leakage/
│
├── dashboard/
│   ├── dashboard_preview.png       # Static preview of the Power BI dashboard
│   └── e-comm_dashboard.pbix       # Interactive Power BI dashboard
│
├── data/
│   ├── raw/                        # Original Kaggle dataset (unmodified)
│   └── cleaned/                    # Normalized CSVs generated after ETL
│
├── docs/
│   ├── ERD.md                      # Entity relationship diagram and modeling rationale
│   ├── ERD.png                     # Visual ERD built in dbdiagram.io
│   ├── architecture.md             # Pipeline architecture and workflow overview
│   ├── architecture_ETL.png        # ETL flow diagram
│   └── data_modeling.md            # Normalization decisions and SQL modeling notes
│
├── sql/
│   ├── 01_schema.sql               # Creates normalized tables with keys and constraints
│   ├── 02_data_loading.sql         # Loads staging data and standardizes date fields
│   ├── 03_revenue_analysis.sql     # Gross revenue, return loss, net revenue, return rate
│   ├── 04_customer_analysis.sql    # Customer value, return behavior, and leakage exposure
│   ├── 05_product_analysis.sql     # Product revenue, return behavior, and loss ranking
│   ├── 06_category_analysis.sql    # Category-level revenue, return rates, and leakage impact
│   ├── 07_data_validation.sql      # ETL reconciliation, duplicate checks, and data quality tests
│   ├── 08_pareto_analysis.sql      # Cumulative distribution of return-related product loss
│   ├── 09_join_pitfall_demo.sql    # Demonstrates inflated metrics from non-deduplicated joins
│   ├── 10_time_analysis.sql        # Monthly order, revenue, return loss, and return rate trends
│   ├── 11_customer_behavior_analysis.sql  # Customer behavior risk and financial impact segmentation
│   └── 12_cohort_analysis.sql      # Cohort-based repeat purchase and retention analysis
│
├── README.md
└── license

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
