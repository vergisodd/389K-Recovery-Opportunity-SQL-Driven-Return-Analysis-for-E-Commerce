# Data Modeling & Preparation

This document covers the decisions made in transforming raw Kaggle e-commerce data into a structured relational schema suitable for return leakage analysis.

---

## 1. Starting Point: Raw Data

The source dataset is a single denormalized CSV containing one row per order, with customer attributes, product attributes, and return information all mixed into the same row.

**Problems with the raw format:**
- Customer data (name, region) is repeated across every order for that customer
- Product data (category, price) is repeated across every order containing that product
- Return information (a sparse attribute — most orders have no return) adds null-heavy columns to every row
- Aggregating across dimensions (e.g. total return loss by category) requires careful filtering to avoid double-counting

**Solution:** Decompose into a normalized relational schema.

---

## 2. Normalization Decisions

### Customers table
Customer attributes appear many times in the raw data — once per order. Extracting them into a `customers` table with a `customer_id` primary key eliminates redundancy and means customer data is updated in one place.

### Products table
Same reasoning as customers. Category and pricing information belongs in a `products` table — not repeated across every order row. This also makes category-level aggregation cleaner (join to `products.category` rather than relying on a denormalized column that might be inconsistently populated).

### Orders table
The orders table is the transactional core — one row per order, containing `customer_id`, `product_id`, `order_date`, and `order_value`. It acts as the hub of the star schema.

**Note on order_items:** The dataset contains one product per order. No separate `order_items` table is needed. If the business were extended to support multi-item orders, `order_items` would be introduced between `orders` and `products`.

### Returns table
Returns are a sparse attribute — roughly 5.5% of orders have a return. Rather than adding return columns (mostly NULL) to every order row, returns are stored in a separate table linked to `orders` via `order_id`.

This keeps the orders table clean and makes it easy to:
- Calculate gross revenue without return contamination (`SELECT SUM(order_value) FROM orders`)
- Calculate return loss precisely (`SELECT SUM(o.order_value) FROM orders o JOIN returns r USING (order_id)`)
- Left-join returns optionally when you need both returned and non-returned orders in the same query

---

## 3. ETL Transformations

All transformations are performed in SQL within `02_data_loading.sql`. No external tools or scripts are used.

| Transform | Detail |
|---|---|
| Date standardization | All dates cast to `DATE` type in `YYYY-MM-DD` format |
| Numeric casting | `order_value` and `unit_price` cast from VARCHAR to `DECIMAL(10,2)` |
| Null handling | Missing return fields stored as NULL (not zero) to avoid distorting aggregations |
| Deduplication | Duplicate order records removed using `ROW_NUMBER()` window function partitioned by `order_id` |
| Derived fields | `return_loss` computed as `order_value` where a matching return exists, else 0; `net_revenue = order_value - return_loss` |

---

## 4. Schema Validation

After loading, the following checks were run to verify data integrity:

```sql
-- Check for orphaned returns (returns with no matching order)
SELECT COUNT(*) FROM returns r
LEFT JOIN orders o USING (order_id)
WHERE o.order_id IS NULL;

-- Check for orders with no matching customer
SELECT COUNT(*) FROM orders o
LEFT JOIN customers c USING (customer_id)
WHERE c.customer_id IS NULL;

-- Check for null order values
SELECT COUNT(*) FROM orders WHERE order_value IS NULL;

-- Verify return rate is in expected range
SELECT
    COUNT(r.return_id) * 100.0 / COUNT(o.order_id) AS return_rate_pct
FROM orders o
LEFT JOIN returns r USING (order_id);
```

All checks passed. Return rate of 5.52% is consistent with the raw data.

---

## 5. Why This Structure Matters for Analysis

The normalized schema makes the following analytical patterns efficient and unambiguous:

**Multi-level aggregation:**
```sql
-- Revenue and return loss by category — clean, no double counting
SELECT
    p.category,
    SUM(o.order_value)                                              AS gross_revenue,
    SUM(CASE WHEN r.return_id IS NOT NULL THEN o.order_value END)  AS return_loss
FROM products p
JOIN orders o   USING (product_id)
LEFT JOIN returns r USING (order_id)
GROUP BY p.category;
```

**Customer-level return risk:**
```sql
-- Return rate per customer using LEFT JOIN to preserve customers with no returns
SELECT
    c.customer_id,
    COUNT(o.order_id)                                              AS total_orders,
    COUNT(r.return_id)                                             AS total_returns,
    ROUND(COUNT(r.return_id) * 100.0 / COUNT(o.order_id), 2)      AS return_rate_pct
FROM customers c
LEFT JOIN orders  o USING (customer_id)
LEFT JOIN returns r USING (order_id)
GROUP BY c.customer_id;
```

**Product Pareto:**
```sql
-- Rank products by return loss to identify leakage concentration
WITH product_loss AS (
    SELECT
        product_id,
        SUM(CASE WHEN r.return_id IS NOT NULL THEN o.order_value ELSE 0 END) AS return_loss
    FROM orders o
    LEFT JOIN returns r USING (order_id)
    GROUP BY product_id
)
SELECT
    product_id,
    return_loss,
    RANK() OVER (ORDER BY return_loss DESC) AS loss_rank,
    SUM(return_loss) OVER ()               AS total_loss,
    return_loss * 100.0 / SUM(return_loss) OVER () AS pct_of_total
FROM product_loss
ORDER BY loss_rank;
```
