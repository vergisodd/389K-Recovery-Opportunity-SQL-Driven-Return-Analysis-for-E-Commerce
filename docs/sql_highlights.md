# SQL Highlights

This document walks through the key analytical queries in this project — the techniques used, why each approach was chosen, and what the results revealed.

For the full scripts, see the [`/sql`](.) folder.

---

## 1. Customer Return Risk Segmentation

This analysis separates **behavioral risk** from **financial impact** so customers are not treated as a single return group.

**Why this matters:**
Most return systems fail because they apply blanket rules across the customer base. That can penalize loyal customers while missing the groups actually creating meaningful return-related loss.

```sql
WITH customer_orders AS (
    SELECT
        o.customer_id,
        COUNT(o.order_id)                                                      AS total_orders,
        ROUND(SUM(o.total_amount), 2)                                          AS total_revenue,
        COUNT(r.return_id)                                                     AS total_returns,
        ROUND(COALESCE(SUM(CASE WHEN r.return_id IS NOT NULL
                               THEN o.total_amount END), 0), 2)                AS return_loss
    FROM orders o
    LEFT JOIN returns r ON o.order_id = r.order_id
    GROUP BY o.customer_id
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
FROM filtered
WHERE total_orders >= 3
ORDER BY return_loss DESC, return_rate DESC;
```

**Segment results:**

| Behavior Segment | Customers | Avg Return Rate (%) | Total Revenue | Total Return Loss | Share of Total Loss (%) | Avg Loss per Customer |
|:---|---:|---:|---:|---:|---:|---:|
| High Risk | 42 | 53.41 | 27,610.66 | 19,317.39 | 5.35 | 459.94 |
| Moderate Risk | 903 | 26.16 | 724,253.83 | 206,387.22 | 57.20 | 228.56 |
| Low Risk | 628 | 14.44 | 771,076.21 | 135,131.30 | 37.45 | 215.18 |
| No Returns | 6,187 | 0.00 | 4,292,312.10 | 0.00 | 0.00 | 0.00 |

**Key insight:**
The most extreme returners are not the main financial problem. Although the High Risk segment shows the highest average return rate, it contributes only **5.35%** of total return-related loss. The larger **Moderate Risk** segment drives **57.2%** of leakage through scale — not through extreme individual behavior.

**What this means for policy:**
A blanket return restriction policy would create friction for healthy customers while failing to reduce the main source of loss. A better strategy is to monitor extreme returners separately while prioritizing investigation into the broader Moderate Risk segment.

> Full script → [`04_customer_analysis.sql`](04_customer_analysis.sql) · [`11_customer_behavior_analysis.sql`](11_customer_behavior_analysis.sql)

---

## 2. Product Revenue Leakage Ranking

This analysis ranks products by return-related financial loss using product-level revenue, return volume, and leakage metrics.

**Why this matters:**
A product may have a high return rate without being the biggest business problem. Looking at both return behavior and financial loss identifies where intervention matters most.

```sql
WITH product_leakage AS (
    SELECT
        p.product_id,
        p.category,
        COUNT(o.order_id)                                                       AS total_orders,
        ROUND(SUM(o.total_amount), 2)                                           AS gross_revenue,
        COUNT(r.order_id)                                                       AS return_orders,
        ROUND(
            COALESCE(SUM(CASE WHEN r.order_id IS NOT NULL THEN o.total_amount END), 0),
            2
        )                                                                       AS return_loss
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
    RANK() OVER (ORDER BY return_loss DESC)                 AS loss_rank
FROM filtered
ORDER BY return_loss DESC
LIMIT 10;
```

**Top 10 products by return loss:**

| Product ID | Category | Total Orders | Gross Revenue | Return Loss | Loss Rate | Return Rate | Loss Rank |
|:---|:---|---:|---:|---:|---:|---:|---:|
| P246300 | Home | 3 | 3,387.94 | 2,756.52 | 0.8136 | 0.3333 | 1 |
| P247404 | Electronics | 3 | 2,386.33 | 2,374.97 | 0.9952 | 0.6667 | 2 |
| P215448 | Fashion | 3 | 1,710.13 | 1,638.32 | 0.9580 | 0.6667 | 3 |
| P249949 | Fashion | 3 | 4,724.99 | 1,627.44 | 0.3444 | 0.3333 | 4 |
| P205121 | Toys | 3 | 1,492.90 | 1,449.95 | 0.9712 | 0.3333 | 5 |
| P229733 | Sports | 4 | 1,632.79 | 1,356.72 | 0.8309 | 0.2500 | 6 |
| P225938 | Sports | 3 | 3,921.18 | 1,325.94 | 0.3381 | 0.3333 | 7 |
| P227683 | Toys | 3 | 1,354.62 | 1,313.35 | 0.9695 | 0.6667 | 8 |
| P218888 | Home | 3 | 1,453.23 | 1,312.28 | 0.9030 | 0.3333 | 9 |
| P225151 | Home | 3 | 1,854.08 | 1,094.35 | 0.5902 | 0.3333 | 10 |

**Key insight:**
Several top-ranked products show loss rates above 95% — return-related loss is consuming nearly all the revenue those products generated. A product does not need high order volume to become a major leakage source. A small number of returned orders on a low-volume item can still destroy most of its revenue contribution.

> Full script → [`05_product_analysis.sql`](05_product_analysis.sql)

---

## 3. Pareto Loss Analysis — Cumulative Distribution

This analysis tests whether a small subset of products is responsible for most return-related losses.

**Why this matters:**
If return loss is highly concentrated, the business can focus resources on a small number of products. If it is spread broadly, recovery efforts need to be wider.

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
        SUM(total_loss) OVER ()                                    AS total_loss_all,
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

**Key insight:**
Loss is concentrated in the top products, but not strongly enough to support a clean 80/20 story. The distribution is broader than expected — recovery efforts need to cover more ground than a simple "fix the top 5 SKUs" approach.

> Full script → [`08_pareto_analysis.sql`](08_pareto_analysis.sql)

---

## 4. Cohort Analysis — Repeat Purchase Retention

Customers are grouped by first purchase month and tracked by later activity to measure repeat purchase behaviour over time.

**Why this matters:**
Cohort analysis tests whether repeat purchase is stable across acquisition periods or whether engagement declines over time for specific cohorts.

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
    JOIN first_purchase f ON o.customer_id = f.customer_id
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
    cd.months_since_first_order,
    cd.active_customers,
    ROUND(cd.active_customers * 100.0 / NULLIF(cs.cohort_customers, 0), 2) AS retention_rate_pct
FROM cohort_data cd
JOIN cohort_size cs ON cd.cohort_month = cs.cohort_month
WHERE cd.months_since_first_order > 0   -- month 0 excluded: 100% retention there is trivially true
ORDER BY cd.cohort_month, cd.months_since_first_order;
```

**Observed activity rates (month 1 and ~12 months):**

| Cohort | Month 0 Customers | Month 1 Activity Rate | ~12-Month Activity Rate |
|:---|---:|---:|---:|
| Oct 2023 | 961 | 11.2% | 12.3% |
| Nov 2023 | 795 | 12.1% | 13.7% |
| Dec 2023 | 795 | — | 12.6% |
| Oct 2024 | 700 | 11.7% | — |

**Important limitation:**
The dataset contains orders from Oct–Dec 2023 and Oct–Dec 2024 only. Months 2–9 are missing, so this analysis cannot measure continuous retention curves. It is directional only.

**Key insight:**
Repeat purchase activity is stable across cohorts, staying in the ~11–13% range. There is no visible cohort decay pattern — repeat behaviour appears structurally consistent rather than time-dependent.

> Full script → [`12_cohort_analysis.sql`](12_cohort_analysis.sql)

---

## 5. Return Reason Breakdown

Return reasons are analysed by volume, revenue loss, category, region, and customer risk segment to identify root causes behind the leakage figures.

**Why this matters:**
Knowing *where* loss is concentrated is only half the picture. Knowing *why* customers return determines whether the fix is a content change, a fulfilment fix, a policy adjustment, or a product quality investigation.

```sql
-- Actionability classification: reason → responsible team → intervention
SELECT
    r.return_reason,
    COUNT(*)                        AS return_count,
    ROUND(SUM(o.total_amount), 2)   AS return_loss,
    CASE r.return_reason
        WHEN 'Defective'           THEN 'Product / QA — investigate supplier or manufacturing defects'
        WHEN 'Not as described'    THEN 'Content team — improve descriptions, images, and sizing guides'
        WHEN 'Missing/Wrong item'  THEN 'Fulfilment / Ops — audit pick-pack accuracy and shipping labels'
        WHEN 'No longer needed'    THEN 'Policy / CRM — review return window and high-frequency return flags'
        WHEN 'Slow delivery'       THEN 'Logistics — review carrier SLAs and checkout delivery estimates'
        ELSE                            'Unclassified — review manually'
    END AS recommended_action
FROM returns r
JOIN orders o ON r.order_id = o.order_id
GROUP BY r.return_reason
ORDER BY return_loss DESC;
```

**Key insight:**
"Not as described" leads on total revenue loss ($105K) while "Defective" leads on average order value per return ($203). These are different problems requiring different interventions — one is a content and expectation issue, the other is a product quality issue.

> Full script → [`13_return_reason_analysis.sql`](13_return_reason_analysis.sql)

---

## 6. True Economic Cost of Returns

Standard return analysis reports revenue loss. This query adds the two hidden cost layers: margin reversed and shipping unrecovered.

**Why this matters:**
A returned order costs more than the refund. The business also loses the profit margin it had already earned on the sale, plus the outbound shipping cost it cannot recover. The headline $389K revenue loss figure understates the real economic damage.

```sql
SELECT
    p.category,
    COUNT(r.return_id)                                                        AS return_count,
    ROUND(SUM(o.total_amount), 2)                                             AS revenue_loss,
    ROUND(SUM(o.profit_margin), 2)                                            AS margin_loss,
    ROUND(SUM(o.shipping_cost), 2)                                            AS shipping_loss,
    ROUND(SUM(o.total_amount + o.profit_margin + o.shipping_cost), 2)         AS total_economic_loss,
    ROUND((SUM(o.profit_margin) + SUM(o.shipping_cost)) * 100.0 /
          NULLIF(SUM(o.total_amount + o.profit_margin + o.shipping_cost), 0),
          2)                                                                   AS hidden_cost_pct,
    RANK() OVER (ORDER BY SUM(o.total_amount + o.profit_margin + o.shipping_cost) DESC) AS economic_loss_rank,
    RANK() OVER (ORDER BY SUM(o.total_amount) DESC)                           AS revenue_loss_rank
FROM returns r
JOIN orders   o ON r.order_id  = o.order_id
JOIN products p ON o.product_id = p.product_id
GROUP BY p.category
ORDER BY total_economic_loss DESC;
```

**Key insight:**
Total economic loss per return is materially higher than revenue loss alone. Categories with high average margins — Electronics in particular — lose proportionally more when returns occur than the revenue figure suggests. The `economic_loss_rank` vs `revenue_loss_rank` columns reveal where the ranking changes once hidden costs are included.

> Full script → [`14_profit_margin_analysis.sql`](14_profit_margin_analysis.sql)
