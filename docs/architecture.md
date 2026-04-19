# Project Architecture

## Pipeline Overview

```
┌─────────────────────────────────────────────────────────────┐
│  SOURCE LAYER                                               │
│  Kaggle CSV — raw, denormalized, single wide file           │
└─────────────────────────────┬───────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  STAGING LAYER                                              │
│  staging_ecommerce — full raw data loaded as-is             │
│  Purpose: preserve source integrity before any transforms   │
└─────────────────────────────┬───────────────────────────────┘
                              │
                              ▼ SQL ETL
┌─────────────────────────────────────────────────────────────┐
│  ETL LAYER                                                  │
│  • Date standardization                                     │
│  • Column type casting                                      │
│  • Derived field calculation (return_loss, net_revenue)     │
│  • Deduplication and null handling                          │
└─────────────────────────────┬───────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  NORMALIZED LAYER                                           │
│  customers / products / orders / returns                    │
│  Relational schema with FK constraints                      │
│  See ERD.md for full schema and relationship details        │
└─────────────────────────────┬───────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  ANALYTICAL LAYER                                           │
│  SQL scripts using CTEs, window functions, aggregations     │
│  03_revenue_analysis.sql  — KPIs and leakage totals         │
│  04_customer_analysis.sql — LTV ranking, risk segmentation  │
│  05_product_analysis.sql  — Pareto, loss ranking, flagging  │
│  06_category_analysis.sql — Category return rates and loss  │
└─────────────────────────────┬───────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  INSIGHT LAYER                                              │
│  Power BI Dashboard                                         │
│  • Revenue & Leakage overview                               │
│  • Customer segmentation & risk scoring                     │
│  • Product Pareto analysis                                  │
│  • Category performance (Electronics vs Fashion focus)      │
└─────────────────────────────────────────────────────────────┘
```

---

## Layer-by-Layer Breakdown

### 1. Source Layer

The raw data is a single wide CSV from Kaggle containing transactional, customer, product, and return information mixed into one flat file. It is stored untouched in `data/raw/` to preserve source integrity.

### 2. Staging Layer

The raw file is loaded into a single denormalized staging table (`staging_ecommerce`) using `02_data_loading.sql`. No transforms happen here — the goal is to get the data into SQL cleanly so all subsequent work is done in-database rather than in spreadsheets or external tools.

**Why stage first?**
Staging decouples ingestion from transformation. If a transform has to be rolled back, the raw data is always intact and re-loadable without going back to the original file.

### 3. ETL Layer

Also handled in `02_data_loading.sql`, the ETL step performs:

- Date parsing and standardization to `YYYY-MM-DD`
- Numeric type casting for `order_value` and `unit_price`
- Derivation of `return_loss` (order value × return flag) and `net_revenue`
- Deduplication of any duplicate order records
- Null handling for missing return fields (left as NULL rather than zero to avoid distorting aggregations)

All transformations are written in standard SQL compatible with both SQLite and PostgreSQL.

### 4. Normalized Layer

The staging table is decomposed into four relational tables via `INSERT INTO ... SELECT` statements. Foreign key constraints are defined in `01_schema.sql`.

See [`docs/ERD.md`](ERD.md) for the full schema, relationship definitions, and design rationale.

### 5. Analytical Layer

Four SQL scripts perform the analysis, each building on the normalized schema:

| Script | Purpose | Key Techniques |
|---|---|---|
| `03_revenue_analysis.sql` | Gross revenue, return loss, net revenue, return rate | Aggregation, conditional SUM |
| `04_customer_analysis.sql` | LTV ranking, return frequency, risk segmentation | LEFT JOIN, CASE, GROUP BY |
| `05_product_analysis.sql` | Revenue by SKU, loss ranking, 100%-return flagging | CTE, RANK() window function |
| `06_category_analysis.sql` | Revenue, return rate, and loss by category | Multi-level aggregation, JOIN chain |

### 6. Insight Layer

Results are visualized in a Power BI dashboard covering four pages: revenue overview, customer analysis, product analysis, and category analysis. The dashboard is designed to surface the same four-layer structure as the SQL analysis, making findings traceable back to specific queries.

---

## Design Principles

**SQL-centric.** All data transformation and analysis happens in SQL — no Python preprocessing, no spreadsheet manipulation. This makes the pipeline reproducible in any environment with a SQL engine.

**Layered separation.** Each layer has a single responsibility. Source data is never modified. Staging is never used for analysis. The normalized schema is the single source of truth for all analytical queries.

**Scalable by design.** The normalized schema supports extension without restructuring — adding a `return_reason` column to `returns`, a `region` dimension to `customers`, or a time-series layer for trend analysis requires no changes to the existing joins or queries.

**Reproducible.** Running `01_schema.sql` → `02_data_loading.sql` → any analysis script in order produces the same results from the same source data every time.

