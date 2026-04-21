-- =========================
-- 14_PROFIT_MARGIN_ANALYSIS.SQL
-- True economic cost of returns accounting for margin and shipping
-- =========================
 
-- NOTE ON FIELDS:
-- profit_margin = absolute dollar profit on the order (not a percentage)
-- shipping_cost = cost of outbound shipping paid by the business
-- A returned order loses: the revenue (total_amount) + the margin that
-- was never recovered + the shipping cost that cannot be recouped.
-- Together these three figures represent the full economic cost of a return.
 
-- =========================
-- 1. Business-level true cost of returns
-- Compares revenue loss (the visible number) against
-- margin loss and shipping loss (the hidden costs).
-- =========================
SELECT
    COUNT(r.return_id)                                                AS total_returns,
 
    -- Revenue loss: the order value that was refunded
    ROUND(SUM(o.total_amount), 2)                                     AS revenue_loss,
 
    -- Margin loss: the profit that was earned and then reversed
    ROUND(SUM(o.profit_margin), 2)                                    AS margin_loss,
 
    -- Shipping loss: outbound shipping cost that cannot be recovered
    ROUND(SUM(o.shipping_cost), 2)                                    AS shipping_loss,
 
    -- Full economic cost: everything the business loses per return
    ROUND(SUM(o.total_amount + o.profit_margin + o.shipping_cost), 2) AS total_economic_loss,
 
    -- Average revenue loss per return
    ROUND(AVG(o.total_amount), 2)                                     AS avg_revenue_loss_per_return,
 
    -- Average full economic loss per return
    ROUND(AVG(o.total_amount + o.profit_margin + o.shipping_cost), 2) AS avg_economic_loss_per_return
FROM returns r
JOIN orders o
    ON r.order_id = o.order_id;
 
-- =========================
-- 2. Category-level true cost of returns
-- Ranks categories by full economic loss rather than revenue loss alone.
-- The ranking may differ — a category with moderate revenue loss
-- but high margins loses proportionally more when returns occur.
-- =========================
WITH category_costs AS (
    SELECT
        p.category,
        COUNT(r.return_id)                                                AS return_count,
        ROUND(SUM(o.total_amount), 2)                                     AS revenue_loss,
        ROUND(SUM(o.profit_margin), 2)                                    AS margin_loss,
        ROUND(SUM(o.shipping_cost), 2)                                    AS shipping_loss,
        ROUND(SUM(o.total_amount + o.profit_margin + o.shipping_cost), 2) AS total_economic_loss,
        ROUND(AVG(o.profit_margin), 2)                                    AS avg_margin_per_return
    FROM returns r
    JOIN orders   o ON r.order_id  = o.order_id
    JOIN products p ON o.product_id = p.product_id
    GROUP BY p.category
)
SELECT
    category,
    return_count,
    revenue_loss,
    margin_loss,
    shipping_loss,
    total_economic_loss,
    avg_margin_per_return,
    -- Show how much of economic loss is hidden beyond just revenue
    ROUND((margin_loss + shipping_loss) * 100.0 /
          NULLIF(total_economic_loss, 0), 2)                          AS hidden_cost_pct,
    RANK() OVER (ORDER BY total_economic_loss DESC)                   AS economic_loss_rank,
    RANK() OVER (ORDER BY revenue_loss DESC)                          AS revenue_loss_rank
FROM category_costs
ORDER BY total_economic_loss DESC;
 
-- =========================
-- 3. Returns on negative-margin orders
-- These are the most damaging returns — the business was already
-- losing money on the sale before the return happened.
-- Returning a negative-margin order compounds the loss.
-- =========================
SELECT
    CASE
        WHEN o.profit_margin < 0  THEN 'Negative Margin'
        WHEN o.profit_margin = 0  THEN 'Zero Margin'
        WHEN o.profit_margin <= 10 THEN 'Low Margin (0–10)'
        WHEN o.profit_margin <= 50 THEN 'Mid Margin (10–50)'
        ELSE                           'High Margin (50+)'
    END                                                               AS margin_band,
    COUNT(*)                                                          AS return_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2)               AS pct_of_returns,
    ROUND(SUM(o.total_amount), 2)                                     AS revenue_loss,
    ROUND(SUM(o.profit_margin), 2)                                    AS margin_loss,
    ROUND(SUM(o.shipping_cost), 2)                                    AS shipping_loss,
    ROUND(SUM(o.total_amount + o.profit_margin + o.shipping_cost), 2) AS total_economic_loss,
    ROUND(AVG(o.total_amount), 2)                                     AS avg_order_value
FROM returns r
JOIN orders o
    ON r.order_id = o.order_id
GROUP BY margin_band
ORDER BY
    CASE margin_band
        WHEN 'Negative Margin'     THEN 1
        WHEN 'Zero Margin'         THEN 2
        WHEN 'Low Margin (0–10)'   THEN 3
        WHEN 'Mid Margin (10–50)'  THEN 4
        WHEN 'High Margin (50+)'   THEN 5
    END;
 
-- =========================
-- 4. Margin-adjusted return rate by category
-- Standard return rate = returned orders / total orders.
-- Margin-adjusted return rate weights each return by the margin
-- lost relative to total margin earned — a more economically
-- accurate view of which categories are truly most at risk.
-- =========================
WITH category_summary AS (
    SELECT
        p.category,
        COUNT(o.order_id)                                             AS total_orders,
        COUNT(r.return_id)                                            AS returned_orders,
        ROUND(SUM(o.total_amount), 2)                                 AS gross_revenue,
        ROUND(SUM(o.profit_margin), 2)                                AS gross_margin,
        ROUND(
            COALESCE(SUM(CASE WHEN r.return_id IS NOT NULL
                              THEN o.total_amount END), 0), 2)        AS revenue_loss,
        ROUND(
            COALESCE(SUM(CASE WHEN r.return_id IS NOT NULL
                              THEN o.profit_margin END), 0), 2)       AS margin_loss,
        ROUND(
            COALESCE(SUM(CASE WHEN r.return_id IS NOT NULL
                              THEN o.shipping_cost END), 0), 2)       AS shipping_loss
    FROM products p
    JOIN orders   o ON p.product_id = o.product_id
    LEFT JOIN returns r ON o.order_id = r.order_id
    GROUP BY p.category
)
SELECT
    category,
    total_orders,
    returned_orders,
    gross_revenue,
    gross_margin,
    revenue_loss,
    margin_loss,
    shipping_loss,
    -- Standard return rate (order count based)
    ROUND(returned_orders * 1.0 / NULLIF(total_orders, 0), 4)        AS order_return_rate,
    -- Revenue return rate (what % of revenue was lost to returns)
    ROUND(revenue_loss / NULLIF(gross_revenue, 0), 4)                 AS revenue_return_rate,
    -- Margin return rate (what % of earned margin was lost to returns)
    ROUND(margin_loss / NULLIF(gross_margin, 0), 4)                   AS margin_return_rate
FROM category_summary
ORDER BY margin_return_rate DESC;
 
-- =========================
-- 5. High-value, high-margin returned orders
-- Identifies individual orders where the economic loss is largest —
-- a small number of high-margin returns can account for a
-- disproportionate share of total economic damage.
-- =========================
SELECT
    o.order_id,
    o.customer_id,
    p.category,
    r.return_reason,
    o.total_amount,
    o.profit_margin,
    o.shipping_cost,
    ROUND(o.total_amount + o.profit_margin + o.shipping_cost, 2)      AS total_economic_loss,
    o.order_date,
    r.request_date
FROM returns r
JOIN orders   o ON r.order_id  = o.order_id
JOIN products p ON o.product_id = p.product_id
WHERE o.profit_margin > 0   -- focus on orders that were genuinely profitable before return
ORDER BY total_economic_loss DESC
LIMIT 20;
