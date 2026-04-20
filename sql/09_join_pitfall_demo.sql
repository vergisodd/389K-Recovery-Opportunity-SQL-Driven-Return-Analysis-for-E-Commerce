-- WRONG: Inflated revenue due to join

SELECT SUM(o.total_amount)
FROM orders o
JOIN returns r ON o.order_id = r.order_id;

-- CORRECT: Aggregate before join
WITH returned_orders AS (
    SELECT DISTINCT order_id
    FROM returns
)
SELECT SUM(o.total_amount)
FROM orders o
JOIN returned_orders r ON o.order_id = r.order_id;
