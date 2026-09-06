-- Monthly recognized revenue
-- Grain: one row per delivery month.
-- Business rule: Recognized revenue includes only completed items
-- and is assigned to the month in which they were delivered.

SELECT
  DATE_TRUNC(DATE(delivered_at), MONTH) AS revenue_month,
  COUNT(DISTINCT order_id) AS completed_orders,
  COUNT(*) AS completed_items,
  ROUND(SUM(CAST(sale_price AS NUMERIC)), 2) AS recognized_revenue,
  ROUND(
    SAFE_DIVIDE(
      SUM(CAST(sale_price AS NUMERIC)),
      COUNT(DISTINCT order_id)
    ),
    2
  ) AS average_order_value
FROM `bigquery-public-data.thelook_ecommerce.order_items`
WHERE status = 'Complete'
  AND delivered_at IS NOT NULL
GROUP BY revenue_month
ORDER BY revenue_month;