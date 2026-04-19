# E-Commerce Revenue Leakage Analysis
![SQL](https://img.shields.io/badge/SQL-Data%20Analysis-blue)
![Type](https://img.shields.io/badge/Project-Analytics%20Case%20Study-green)
![Status](https://img.shields.io/badge/Status-Completed-brightgreen)
![Domain](https://img.shields.io/badge/Domain-E--commerce-orange)


> **$389K in return-driven revenue loss identified** across a $5.87M operation — with SQL-driven segmentation pinpointing exactly where to act first.

This project uses SQL end-to-end to quantify, locate, and prioritize revenue leakage from product returns in an e-commerce business. From raw Kaggle data to a normalized relational schema to a Power BI dashboard, every step is documented and reproducible.

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

> Full SQL scripts → [`/sql`](sql/)

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

## Analytical Approach

| Layer | Focus | Key Output |
|:---|:---|:---|
| Revenue Overview | Baseline health metrics | $389K leakage on $5.87M revenue |
| Customer Analysis | LTV vs. return risk separation | Risk segments: High / Moderate / Low |
| Product Analysis | SKU-level Pareto of losses | Top 5 products = outsized leakage share |
| Category Analysis | Return rate + loss by segment | Electronics = highest loss · Fashion = highest rate |

<br>

## Business Recommendations

Based on the SQL findings, the highest-leverage interventions are:

1. **Audit the top 5 loss products first** — a small SKU set drives a disproportionate share of leakage; quality, description, or fulfillment issues are the likely culprits
2. **Investigate Electronics** — high revenue + high return rate = highest-priority category for root cause analysis
3. **Address Fashion's return rate** — 8.05% likely reflects an expectation mismatch problem (sizing info, product photography) rather than a quality defect
4. **Separate customer value from return risk** — blunt return policies risk penalising your best customers
5. **Build a recurring return dashboard** — track return rate, loss, and high-risk segments monthly so leakage trends surface before they compound

<br>

## If I Were the Analyst Here

After delivering these findings, my next three priorities would be:

- **Add a `return_reason` field** — right now we know *where* leakage is concentrated but not *why*. One column unlocks root cause analysis.
- **Run a cohort analysis on high-return customers** — are they new customers with misaligned expectations, or long-term customers with quality concerns? The answer changes the intervention entirely.
- **Set return rate alert thresholds** — Electronics at 7.3% is already elevated; a dashboard trigger at 8% gives the team a leading indicator before losses compound.

<br>

## Dataset

[Kaggle: E-Commerce Dataset — Orders & Returns](https://www.kaggle.com/datasets/)

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

