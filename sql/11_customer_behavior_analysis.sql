-- ============================================
-- 11_CUSTOMER_BEHAVIOR_ANALYSIS.SQL
-- Customer return behavior risk + financial impact
-- ============================================

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
