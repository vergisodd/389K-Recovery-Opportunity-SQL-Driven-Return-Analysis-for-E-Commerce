WITH first_purchase AS (
    SELECT 
        customer_id,
        MIN(strftime('%Y-%m-01', order_date)) AS cohort_month
    FROM orders
    GROUP BY customer_id
),
customer_activity AS (
    SELECT 
        o.customer_id,
        strftime('%Y-%m-01', o.order_date) AS activity_month,
        f.cohort_month
    FROM orders o
    JOIN first_purchase f ON o.customer_id = f.customer_id
),
cohort_data AS (
    SELECT 
        cohort_month,
        activity_month,
        -- Calculate month difference manually in SQLite
        (strftime('%Y', activity_month) - strftime('%Y', cohort_month)) * 12 +
        (strftime('%m', activity_month) - strftime('%m', cohort_month)) AS months_since_first_order,
        COUNT(DISTINCT customer_id) AS active_customers
    FROM customer_activity
    GROUP BY cohort_month, activity_month
)
SELECT * FROM cohort_data ORDER BY cohort_month, months_since_first_order;
