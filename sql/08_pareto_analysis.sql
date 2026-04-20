WITH product_loss AS (
    SELECT 
        p.product_name,
        SUM(o.total_amount) AS total_loss
    FROM returns r
    JOIN orders o ON r.order_id = o.order_id
    JOIN products p ON o.product_id = p.product_id
    GROUP BY p.product_name
),
ranked AS (
    SELECT *,
        SUM(total_loss) OVER () AS total_all_loss,
        SUM(total_loss) OVER (ORDER BY total_loss DESC) AS cumulative_loss
    FROM product_loss
)
SELECT 
    product_name,
    total_loss,
    cumulative_loss,
    cumulative_loss / total_all_loss AS cumulative_pct
FROM ranked
ORDER BY total_loss DESC;
