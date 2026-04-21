-- =========================
-- 13_RETURN_REASON_ANALYSIS.SQL
-- Return reason breakdown by volume, loss, category, region, and customer segment
-- =========================

-- =========================
-- 1. Overall return reason summary
-- Volume, revenue loss, and share of total returns per reason.
-- This identifies which reasons are driving the most leakage
-- and which are most frequent — they are not always the same.
-- =========================
SELECT
    r.return_reason,
    COUNT(*)                                                          AS return_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2)               AS pct_of_returns,
    ROUND(SUM(o.total_amount), 2)                                     AS return_loss,
    ROUND(SUM(o.total_amount) * 100.0 / SUM(SUM(o.total_amount)) OVER (), 2) AS pct_of_loss,
    ROUND(AVG(o.total_amount), 2)                                     AS avg_order_value
FROM returns r
JOIN orders o
    ON r.order_id = o.order_id
GROUP BY r.return_reason
ORDER BY return_loss DESC;

-- =========================
-- 2. Return reason by category
-- Reveals whether a reason is isolated to one category
-- or systemic across the business.
-- e.g. "Defective" concentrated in Electronics → product quality issue
--      "Not as described" concentrated in Fashion → content/photography issue
-- =========================
SELECT
    p.category,
    r.return_reason,
    COUNT(*)                                                          AS return_count,
    ROUND(SUM(o.total_amount), 2)                                     AS return_loss,
    ROUND(COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER (PARTITION BY p.category), 2)             AS pct_within_category
FROM returns r
JOIN orders   o ON r.order_id  = o.order_id
JOIN products p ON o.product_id = p.product_id
GROUP BY p.category, r.return_reason
ORDER BY p.category, return_loss DESC;

-- =========================
-- 3. Dominant return reason per category
-- Surfaces the single biggest driver of returns for each category.
-- Useful for prioritizing category-specific interventions.
-- =========================
WITH reason_by_category AS (
    SELECT
        p.category,
        r.return_reason,
        COUNT(*)                    AS return_count,
        ROUND(SUM(o.total_amount), 2) AS return_loss,
        RANK() OVER (
            PARTITION BY p.category
            ORDER BY SUM(o.total_amount) DESC
        )                           AS loss_rank
    FROM returns r
    JOIN orders   o ON r.order_id  = o.order_id
    JOIN products p ON o.product_id = p.product_id
    GROUP BY p.category, r.return_reason
)
SELECT
    category,
    return_reason  AS dominant_reason,
    return_count,
    return_loss
FROM reason_by_category
WHERE loss_rank = 1
ORDER BY return_loss DESC;

-- =========================
-- 4. Return reason by region
-- Identifies whether certain return drivers are geographically concentrated,
-- which could indicate fulfilment, logistics, or market-fit issues
-- specific to a region.
-- =========================
SELECT
    o.region,
    r.return_reason,
    COUNT(*)                                                          AS return_count,
    ROUND(SUM(o.total_amount), 2)                                     AS return_loss,
    ROUND(COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER (PARTITION BY o.region), 2)               AS pct_within_region
FROM returns r
JOIN orders o
    ON r.order_id = o.order_id
GROUP BY o.region, r.return_reason
ORDER BY o.region, return_loss DESC;

-- =========================
-- 5. Return reason by customer risk segment
-- Joins return reason to the customer behavior segmentation
-- to understand whether high-risk customers return for different
-- reasons than low-risk customers.
-- e.g. High-risk customers returning for "No longer needed" → policy abuse
--      High-risk customers returning for "Defective" → product quality problem
-- =========================
WITH customer_summary AS (
    SELECT
        o.customer_id,
        COUNT(o.order_id)                                             AS total_orders,
        COUNT(r.return_id)                                            AS total_returns,
        ROUND(COUNT(r.return_id) * 1.0 /
              NULLIF(COUNT(o.order_id), 0), 4)                        AS return_rate
    FROM orders o
    LEFT JOIN returns r ON o.order_id = r.order_id
    GROUP BY o.customer_id
    HAVING COUNT(o.order_id) >= 3
),
segmented AS (
    SELECT
        customer_id,
        CASE
            WHEN return_rate >= 0.50 THEN 'High Risk'
            WHEN return_rate >= 0.20 THEN 'Moderate Risk'
            WHEN total_returns  = 0  THEN 'No Returns'
            ELSE                          'Low Risk'
        END AS behavior_segment
    FROM customer_summary
)
SELECT
    s.behavior_segment,
    r.return_reason,
    COUNT(*)                        AS return_count,
    ROUND(SUM(o.total_amount), 2)   AS return_loss
FROM returns r
JOIN orders   o ON r.order_id  = o.order_id
JOIN segmented s ON o.customer_id = s.customer_id
GROUP BY s.behavior_segment, r.return_reason
ORDER BY s.behavior_segment, return_loss DESC;

-- =========================
-- 6. Actionability classification
-- Tags each return reason with the team responsible for fixing it
-- and the type of intervention required.
-- Turns raw reason data into a prioritized action list.
-- =========================
SELECT
    r.return_reason,
    COUNT(*)                        AS return_count,
    ROUND(SUM(o.total_amount), 2)   AS return_loss,
    CASE r.return_reason
        WHEN 'Defective'           THEN 'Product / QA team — investigate manufacturing or supplier defects'
        WHEN 'Not as described'    THEN 'Content team — improve product descriptions, images, and sizing guides'
        WHEN 'Missing/Wrong item'  THEN 'Fulfilment / Ops team — audit pick-pack accuracy and shipping labels'
        WHEN 'No longer needed'    THEN 'Policy / CRM team — review return window length and return-rate customer flags'
        WHEN 'Slow delivery'       THEN 'Logistics team — review carrier SLAs and delivery estimates shown at checkout'
        ELSE                            'Unclassified — review manually'
    END AS recommended_action
FROM returns r
JOIN orders o
    ON r.order_id = o.order_id
GROUP BY r.return_reason
ORDER BY return_loss DESC;
