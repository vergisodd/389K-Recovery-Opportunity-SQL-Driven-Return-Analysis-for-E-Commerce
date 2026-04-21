WITH customer_orders AS (
    SELECT 
        o.customer_id,
        COUNT(*) AS total_orders,
        SUM(o.order_value) AS total_revenue,
        SUM(CASE WHEN r.order_id IS NOT NULL THEN 1 ELSE 0 END) AS total_returns,
        SUM(CASE 
                WHEN r.order_id IS NOT NULL THEN o.order_value 
                ELSE 0 
            END) AS return_loss
    FROM orders o
    LEFT JOIN returns r 
        ON o.order_id = r.order_id
    GROUP BY o.customer_id
),

customer_behavior AS (
    SELECT 
        customer_id,
        total_orders,
        total_returns,
        total_revenue,
        return_loss,
        return_loss * 1.0 / NULLIF(total_revenue, 0) AS loss_rate,
        total_returns * 1.0 / total_orders AS return_rate,

        -- Risk (behavior-based)
        CASE 
            WHEN total_returns = 0 THEN 'No Returns'
            WHEN total_returns * 1.0 / total_orders > 0.5 THEN 'High Risk'
            WHEN total_returns * 1.0 / total_orders > 0.2 THEN 'Moderate Risk'
            ELSE 'Low Risk'
        END AS risk_segment,

        -- Financial impact (distribution-based using percentiles)
        NTILE(4) OVER (ORDER BY return_loss DESC) AS loss_quartile

    FROM customer_orders
),

final_segmentation AS (
    SELECT 
        *,
        CASE 
            WHEN loss_quartile = 1 THEN 'High Impact'
            WHEN loss_quartile = 2 THEN 'Moderate Impact'
            ELSE 'Low Impact'
        END AS impact_segment
    FROM customer_behavior
)

SELECT 
    risk_segment,
    impact_segment,
    COUNT(*) AS customer_count,
    ROUND(AVG(return_rate), 3) AS avg_return_rate,
    ROUND(SUM(return_loss), 2) AS total_return_loss,
    ROUND(SUM(total_revenue), 2) AS total_revenue
FROM final_segmentation
GROUP BY risk_segment, impact_segment
ORDER BY total_return_loss DESC;
