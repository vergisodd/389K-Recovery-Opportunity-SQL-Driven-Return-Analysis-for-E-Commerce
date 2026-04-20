1. Row count reconciliation

-- Raw vs staging vs final
SELECT COUNT(*) FROM staging_ecommerce;

SELECT 
    (SELECT COUNT(*) FROM orders) AS orders_count,
    (SELECT COUNT(*) FROM returns) AS returns_count;

2. Duplicate check

SELECT order_id, COUNT(*)
FROM staging_ecommerce
GROUP BY order_id
HAVING COUNT(*) > 1;


3. Revenue reconciliation

-- Total revenue before cleaning
SELECT SUM(order_value) FROM staging_ecommerce;

-- After transformation
SELECT SUM(total_amount) FROM orders;


4. Return consistency

-- Ensure returns match orders
SELECT COUNT(*)
FROM returns r
LEFT JOIN orders o ON r.order_id = o.order_id
WHERE o.order_id IS NULL;
