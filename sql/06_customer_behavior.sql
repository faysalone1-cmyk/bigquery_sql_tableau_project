-- Customer behaviour analysis
-- Starting grain: one row per order item.
-- completed_orders grain: one row per completed order.
-- customer_summary grain: one row per registered customer.
-- Final grain: one row per customer segment.
--
-- Segment definitions:
-- No completed purchases: zero completed orders.
-- One-time customer: exactly one completed order.
-- Repeat customer: more than one completed order.

WITH completed_orders AS (
  SELECT
    user_id,
    order_id,
    SUM(CAST(sale_price AS NUMERIC)) AS order_revenue
  FROM `bigquery-public-data.thelook_ecommerce.order_items`
  WHERE status = 'Complete'
    AND delivered_at IS NOT NULL
    AND DATE(delivered_at) < DATE_TRUNC(CURRENT_DATE(), MONTH)
  GROUP BY
    user_id,
    order_id
),

customer_summary AS (
  SELECT
    u.id AS user_id,
    COUNT(co.order_id) AS completed_orders,
    COALESCE(SUM(co.order_revenue), 0) AS recognized_revenue
  FROM `bigquery-public-data.thelook_ecommerce.users` AS u
  LEFT JOIN completed_orders AS co
    ON u.id = co.user_id
  GROUP BY u.id
)

SELECT
  CASE
    WHEN completed_orders = 0 THEN 'No completed purchases'
    WHEN completed_orders = 1 THEN 'One-time customer'
    ELSE 'Repeat customer'
  END AS customer_segment,
  COUNT(*) AS customers,
  SUM(completed_orders) AS completed_orders,
  ROUND(SUM(recognized_revenue), 2) AS recognized_revenue,
  ROUND(AVG(completed_orders), 2) AS average_orders_per_customer,
  ROUND(AVG(recognized_revenue), 2) AS average_revenue_per_customer
FROM customer_summary
GROUP BY customer_segment
ORDER BY recognized_revenue DESC;
