-- Monthly recognized revenue and month-over-month comparison
-- Grain: one row per delivery month.
-- Business rule: Recognized revenue includes only completed items
-- and is assigned to the month in which they were delivered.
-- The current incomplete calendar month is excluded.

WITH monthly_revenue AS (
  SELECT
    DATE_TRUNC(DATE(delivered_at), MONTH) AS revenue_month,
    COUNT(DISTINCT order_id) AS completed_orders,
    COUNT(*) AS completed_items,
    ROUND(SUM(CAST(sale_price AS NUMERIC)), 2)
      AS recognized_revenue,
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
    AND DATE(delivered_at) < DATE_TRUNC(CURRENT_DATE(), MONTH)
  GROUP BY revenue_month
),

revenue_comparison AS (
  SELECT
    *,
    LAG(recognized_revenue) OVER (
      ORDER BY revenue_month
    ) AS previous_month_revenue
  FROM monthly_revenue
)

SELECT
  revenue_month,
  completed_orders,
  completed_items,
  recognized_revenue,
  average_order_value,
  previous_month_revenue,
  ROUND(
    recognized_revenue - previous_month_revenue,
    2
  ) AS revenue_change,
  ROUND(
    SAFE_DIVIDE(
      recognized_revenue - previous_month_revenue,
      previous_month_revenue
    ) * 100,
    2
  ) AS revenue_growth_pct
FROM revenue_comparison
ORDER BY revenue_month;
