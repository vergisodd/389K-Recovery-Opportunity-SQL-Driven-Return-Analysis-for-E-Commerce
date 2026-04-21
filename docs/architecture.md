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
│  • Deduplication via ROW_NUMBER()                           │
│  • Category conflict resolution (modal + tie-breaker)       │
│  • Null handling for sparse return fields                   │
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
│  03 revenue · 04 customer · 05 product · 06 category        │
│  10 time · 11 behavior · 12 cohort                          │
│  13 return reason · 14 profit margin                        │
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
- Deduplication of duplicate order and return records using `ROW_NUMBER()`
- Category conflict resolution using modal value with alphabetical tie-breaker
- Null handling for missing return fields (left as NULL rather than zero to avoid distorting aggregations)

### 4. Normalized Layer

The staging table is decomposed into four relational tables via `INSERT INTO ... SELECT` statements. Foreign key constraints are defined in `01_schema.sql`.

See [`docs/ERD.md`](ERD.md) for the full schema, relationship definitions, and design rationale.

### 5. Analytical Layer

| Script | Purpose | Key Techniques |
|:---|:---|:---|
| `03_revenue_analysis.sql` | Gross revenue, return loss, net revenue, return rate | Aggregation, conditional SUM |
| `04_customer_analysis.sql` | LTV ranking, return frequency, risk segmentation | LEFT JOIN, CASE, GROUP BY |
| `05_product_analysis.sql` | Revenue by SKU, loss ranking, risk classification | CTE, RANK() window function |
| `06_category_analysis.sql` | Revenue, return rate, and loss by category | Multi-level aggregation, JOIN chain |
| `10_time_analysis.sql` | Monthly revenue, return loss, and return rate trends | GROUP BY date, COALESCE |
| `11_customer_behavior_analysis.sql` | Behavioral risk and financial impact segmentation | NTILE(), CASE, filtered CTE |
| `12_cohort_analysis.sql` | Repeat purchase retention by cohort month | MIN(), date arithmetic, month-0 exclusion |
| `13_return_reason_analysis.sql` | Return reason by volume, category, region, and segment | Window functions, PARTITION BY, CASE |
| `14_profit_margin_analysis.sql` | True economic cost of returns including margin and shipping | Multi-column aggregation, margin banding |

### 6. Insight Layer

Results are visualized in a Power BI dashboard covering revenue overview, customer analysis, product analysis, and category analysis. The dashboard is designed to surface the same layered structure as the SQL analysis, making findings traceable back to specific queries.

---

## Design Principles

**SQL-centric.** All data transformation and analysis happens in SQL — no Python preprocessing, no spreadsheet manipulation. This makes the pipeline reproducible in any environment with a SQL engine.

**Layered separation.** Each layer has a single responsibility. Source data is never modified. Staging is never used for analysis. The normalized schema is the single source of truth for all analytical queries.

**Scalable by design.** The normalized schema supports extension without restructuring — adding new dimensions, time-series layers, or additional analytical scripts requires no changes to the existing joins or schema.

**Reproducible.** Running `01_schema.sql` → `02_data_loading.sql` → any analysis script in order produces the same results from the same source data every time.

---

## SQLite-Specific Functions

This project is written for **SQLite**. The following functions are used in the ETL and analytical layers that are SQLite-specific and would require substitution when porting to another database engine:

| SQLite Function | Purpose | PostgreSQL Equivalent |
|:---|:---|:---|
| `strftime('%Y-%m', date)` | Date formatting for grouping | `TO_CHAR(date, 'YYYY-MM')` |
| `printf('%04d-%02d-%02d', y, m, d)` | Zero-padded date assembly | `LPAD` + string concat or `TO_DATE` |
| `instr(string, substring)` | Find position of character in string | `POSITION(substring IN string)` |
| `substr(string, start, length)` | Extract substring by position | `SUBSTRING(string FROM start FOR length)` |
| `PRAGMA foreign_keys = ON` | Enable FK constraint enforcement | FK constraints are on by default |
| `INTEGER PRIMARY KEY AUTOINCREMENT` | Auto-incrementing surrogate key | `SERIAL PRIMARY KEY` or `GENERATED ALWAYS AS IDENTITY` |

All analytical queries (scripts 03–14) use only standard SQL — CTEs, window functions, `GROUP BY`, `CASE`, `JOIN` — and are fully portable to PostgreSQL, DuckDB, or any ANSI-compliant engine without modification. Only the ETL script (`02_data_loading.sql`) requires the substitutions above.
