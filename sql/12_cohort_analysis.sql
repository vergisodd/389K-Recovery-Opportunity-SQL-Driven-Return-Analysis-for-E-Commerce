-- =========================
-- 12_COHORT_ANALYSIS.SQL
-- Cohort-based repeat purchase activity over time
-- =========================

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
