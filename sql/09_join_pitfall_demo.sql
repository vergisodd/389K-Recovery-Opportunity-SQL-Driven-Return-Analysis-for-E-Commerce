-- =========================
-- 09_JOIN_PITFALL_DEMO.SQL
-- Demonstrating why duplicate rows should be removed before analysis
-- =========================

-- WRONG:
-- If the raw/staging layer contains duplicate return rows,
-- joining directly can inflate financial loss.
SELECT
    ROUND(SUM(o.total_amount), 2) AS inflated_return_loss
FROM orders o
JOIN staging_ecommerce s
    ON o.order_id = s.order_id
WHERE s.returned = 'Yes';

-- CORRECT:
-- Deduplicate returned orders first, then calculate loss.
WITH returned_orders AS (
    SELECT DISTINCT order_id
    FROM staging_ecommerce
    WHERE returned = 'Yes'
)
SELECT
    ROUND(SUM(o.total_amount), 2) AS corrected_return_loss
FROM orders o
JOIN returned_orders r
    ON o.order_id = r.order_id;
