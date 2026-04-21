
-- ============================================
-- 11. CUSTOMER BEHAVIOR ANALYSIS (SIMPLIFIED)
-- Risk (Behavior) + Impact (Financial)
-- ============================================

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

-- ============================================
-- RISK SEGMENTATION (BEHAVIOR)
-- ============================================
risk_segmented AS (
    SELECT 
        *,
        CASE 
            WHEN return_rate >= 0.5 THEN 'High Risk'
            WHEN return_rate >= 0.2 THEN 'Moderate Risk'
            ELSE 'Low Risk'
        END AS risk_segment
    FROM base
),

-- ============================================
-- IMPACT SEGMENTATION (FINANCIAL)
-- Top 20% of loss = High Impact
-- ============================================
ranked AS (
    SELECT 
        *,
        NTILE(5) OVER (ORDER BY return_loss DESC) AS loss_quintile
    FROM risk_segmented
)

SELECT 
    customer_id,
    total_orders,
    total_revenue,
    total_returns,
    return_loss,
    ROUND(return_rate, 3) AS return_rate,

    risk_segment,

    CASE 
        WHEN loss_quintile = 1 THEN 'High Impact'
        ELSE 'Low Impact'
    END AS impact_segment

FROM ranked

ORDER BY return_loss DESC;
