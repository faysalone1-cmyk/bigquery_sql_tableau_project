-- Phase 5: monthly order-status preview.
-- One row per completed calendar month of ORDER CREATION.
-- Statuses are current snapshot values, not status as of that month.
-- Each percentage uses all orders created in that month as its denominator.
-- Recent creation cohorts may still have many Processing/Shipped orders.

WITH monthly_orders AS (
  SELECT
    DATE_TRUNC(DATE(created_at), MONTH) AS created_month,
    COUNT(*) AS created_orders,
    COUNTIF(status = 'Processing') AS processing_orders,
    COUNTIF(status = 'Shipped') AS shipped_orders,
    COUNTIF(status = 'Complete') AS complete_orders,
    COUNTIF(status = 'Cancelled') AS cancelled_orders,
    COUNTIF(status = 'Returned') AS returned_orders
  FROM `bigquery-public-data.thelook_ecommerce.orders`
  WHERE created_at IS NOT NULL
    AND DATE(created_at) < DATE_TRUNC(CURRENT_DATE(), MONTH)
  GROUP BY created_month
),

month_bounds AS (
  SELECT
    MIN(created_month) AS first_month,
    MAX(created_month) AS latest_month
  FROM monthly_orders
),

calendar_months AS (
  SELECT month AS created_month
  FROM month_bounds,
    UNNEST(GENERATE_DATE_ARRAY(
      first_month, latest_month, INTERVAL 1 MONTH
    )) AS month
)

SELECT
  c.created_month,
  COALESCE(m.created_orders, 0) AS created_orders,
  COALESCE(m.processing_orders, 0) AS processing_orders,
  COALESCE(m.shipped_orders, 0) AS shipped_orders,
  COALESCE(m.complete_orders, 0) AS complete_orders,
  COALESCE(m.cancelled_orders, 0) AS cancelled_orders,
  COALESCE(m.returned_orders, 0) AS returned_orders,
  COALESCE(m.processing_orders, 0) + COALESCE(m.shipped_orders, 0)
    AS currently_open_orders,
  ROUND(SAFE_DIVIDE(m.cancelled_orders, m.created_orders) * 100, 2)
    AS current_cancelled_share_pct,
  ROUND(SAFE_DIVIDE(m.returned_orders, m.created_orders) * 100, 2)
    AS current_returned_share_pct,
  ROUND(SAFE_DIVIDE(m.complete_orders, m.created_orders) * 100, 2)
    AS current_complete_share_pct
FROM calendar_months AS c
LEFT JOIN monthly_orders AS m
  ON c.created_month = m.created_month
ORDER BY c.created_month;
