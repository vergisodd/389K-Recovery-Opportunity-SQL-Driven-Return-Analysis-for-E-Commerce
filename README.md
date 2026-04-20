# E-Commerce Revenue Leakage Analysis
![SQL](https://img.shields.io/badge/SQL-Data%20Analysis-blue)
![Type](https://img.shields.io/badge/Project-Analytics%20Case%20Study-green)
![Status](https://img.shields.io/badge/Status-Completed-brightgreen)
![Domain](https://img.shields.io/badge/Domain-E--commerce-orange)


> **$389K in return-driven revenue loss identified** across a $5.87M operation — with SQL-driven segmentation pinpointing exactly where to act first.

This project demonstrates advanced SQL for business analysis, including data validation, revenue reconciliation, window-function-based prioritization, and join correctness handling.

<br>

## Dashboard Preview

![E-Commerce Revenue Leakage Dashboard](dashboard/dashboard_preview.png)

> Built in Power BI · Revenue overview · Customer risk segmentation · Product Pareto · Category breakdown

<br>

## Key Findings at a Glance

| Metric | Value |
|:---|---:|
| Gross Revenue | $5,865,293 |
| Return Loss | $388,756 |
| Net Revenue | $5,476,537 |
| Overall Return Rate | 5.52% |

- 🔴 **Electronics** is the top-revenue category — and the largest source of return loss ($166K)
- 🟠 **Fashion** has the highest return rate at **8.05%**, signalling expectation mismatch or fit issues
- 🟡 **Top 5 loss products** account for a disproportionate share of total leakage — a clear Pareto pattern
- 🟢 **High-return customers** are mostly *not* the highest-value customers — risk and value require separate monitoring

<br>

## How to Run This Project

1. Create database
2. Run: sql/01_schema.sql
3. Load data using: sql/02_data_loading.sql
4. Run analysis files in order:
   - 03_revenue_analysis.sql
   - 04_customer_analysis.sql
   - ... 10_time_analysis.sql

## SQL Highlights

This project demonstrates real analytical SQL — not just `SELECT` statements.

### Window function — customer return rate with risk segmentation

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

### CTE + RANK() — product-level revenue leakage ranked by loss

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
### SQL Deep Dive: Pareto Revenue Loss Analysis

One of the key analytical challenges in this project was identifying which products drive the majority of return-related revenue loss.

To solve this, I implemented a Pareto analysis using SQL window functions to rank products and calculate cumulative contribution to total loss.

This allows the business to prioritize high-impact products rather than treating all returns equally.

```sql
WITH product_loss AS (
    SELECT 
        p.product_name,
        SUM(o.total_amount) AS total_loss
    FROM returns r
    JOIN orders o 
        ON r.order_id = o.order_id
    JOIN products p 
        ON o.product_id = p.product_id
    GROUP BY p.product_name
),
ranked AS (
    SELECT 
        product_name,
        total_loss,
        SUM(total_loss) OVER () AS total_loss_all,
        SUM(total_loss) OVER (ORDER BY total_loss DESC) AS cumulative_loss
    FROM product_loss
)
SELECT 
    product_name,
    total_loss,
    cumulative_loss,
    cumulative_loss / total_loss_all AS cumulative_pct
FROM ranked
ORDER BY total_loss DESC;
```

> Full SQL scripts → [`/sql`](sql/)

This query demonstrates:

- Window functions for cumulative analysis
- Ranking logic for prioritization
- Translation of raw data into business decision-making

Using this approach, the business can identify the small subset of products responsible for the majority of losses (Pareto principle).
<br>


## Project Structure

```
ecommerce-revenue-leakage/
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
│   └── 06_category_analysis.sql   # Category return rates + leakage
│
├── dashboard/
│   ├── dashboard_preview.png       # Static preview image
│   └── e-comm_dashboard.pbix       # Power BI dashboard file
│
└── README.md
```


<br>

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

<br>

## Data Validation & Integrity Checks

Ensuring data accuracy was a critical part of this project.

Before performing any analysis, multiple validation checks were implemented to confirm that transformations did not introduce errors or inconsistencies.

These checks ensure that all reported metrics (revenue, return rate, loss) are reliable and reconciled across data layers.

### Validation Checks Performed

- Row count reconciliation between raw and transformed tables  
- Duplicate detection on order-level data  
- Revenue reconciliation before and after transformation  
- Referential integrity between orders and returns  
- Null and missing value checks in key fields

### Example: Revenue Reconciliation Check

```sql
-- Total revenue before cleaning
SELECT SUM(order_value) 
FROM staging_ecommerce;

-- Total revenue after transformation
SELECT SUM(total_amount) 
FROM orders;
```
This check ensures that no revenue is lost or artificially introduced during the transformation process.

Matching totals confirm that aggregation and normalization steps preserve financial accuracy.

These validation steps ensure that all downstream analysis is based on consistent, accurate, and trustworthy data.

> All validation queries are documented in: → [`sql/07_data_validation.sql`](sql/07_data_validation.sql)

## Join Pitfall Demonstration

A naive join between orders and returns can inflate revenue due to duplication.

This project demonstrates:
- incorrect aggregation approach
- corrected approach using deduplication

> Full details → [`sql/09_join_pitfall_demo.sql`](sql/09_join_pitfall_demo.sql)

## Analytical Approach

| Layer | Focus | Key Output |
|:---|:---|:---|
| Revenue Overview | Baseline health metrics | $389K leakage on $5.87M revenue |
| Customer Analysis | LTV vs. return risk separation | Risk segments: High / Moderate / Low |
| Product Analysis | SKU-level Pareto of losses | Top 5 products = outsized leakage share |
| Category Analysis | Return rate + loss by segment | Electronics = highest loss · Fashion = highest rate |

<br>

## Business Recommendations & Prioritization

The goal of this analysis is not only to identify return-related revenue loss, but to prioritize actions that can maximize recovery with minimal effort.

Using SQL-based analysis, key loss drivers were ranked based on their financial impact and return behavior.

### Top Priorities

1. **Focus on High-Loss Products (Pareto Effect)**
   - A small subset of products contributes to a large portion of total revenue loss.
   - These products should be prioritized for investigation (quality issues, sizing, product mismatch).

2. **Target High Return Rate Categories**
   - Categories such as [replace with your actual category, e.g., Fashion] show significantly higher return rates.
   - These may require changes in product descriptions, sizing guides, or customer expectations.

3. **Investigate Repeat Return Behavior**
   - Customers with multiple returns represent higher risk.
   - Policies such as return limits or targeted interventions can reduce losses.

4. **Monitor Return Trends Over Time**
   - If return rates are increasing, this may indicate operational or product issues.
   - Early detection allows proactive correction.
  
### Why This Prioritization Matters

Not all returns have equal business impact.

By focusing on:
- high-value losses instead of all returns  
- top-contributing products instead of all products  
- repeat patterns instead of isolated cases  

The business can allocate resources efficiently and achieve faster revenue recovery.

These recommendations are directly supported by SQL analysis, including:
- product-level loss ranking
- return rate segmentation
- cumulative contribution (Pareto analysis)

<br>

## Customer Behavior Analysis

To better understand return patterns, customers were segmented based on their return behavior.

This analysis identifies high-risk customer groups who contribute disproportionately to return-related losses.

Using SQL, customers were classified into risk segments based on their return rate:

- No Returns
- Low Risk
- Moderate Risk
- High Risk

This segmentation allows the business to:

- Identify customers with consistently high return behavior  
- Apply targeted policies (e.g., return limits or review flags)  
- Reduce loss from repeat return patterns

## If I Were the Analyst Here

After delivering these findings, my next three priorities would be:

- **Add a `return_reason` field** — right now we know *where* leakage is concentrated but not *why*. One column unlocks root cause analysis.
- **Run a cohort analysis on high-return customers** — are they new customers with misaligned expectations, or long-term customers with quality concerns? The answer changes the intervention entirely.
- **Set return rate alert thresholds** — Electronics at 7.3% is already elevated; a dashboard trigger at 8% gives the team a leading indicator before losses compound.

<br>

## Dataset

[Kaggle: E-Commerce Dataset — Orders & Returns](https://www.kaggle.com/datasets/angellawl/e-commerce-dataset-order-and-return?utm_source=chatgpt.com)

<br>

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

