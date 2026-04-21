-- =========================
-- 08_PARETO_ANALYSIS.SQL
-- Cumulative distribution of return-related loss by product
-- =========================

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
        SUM(total_loss) OVER () AS total_loss_all,
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
