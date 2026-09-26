-- Phase 5: validate the monthly order-status preview.
-- Creates a session-only temporary table; does not change permanent views.
-- Run the whole script, then open the final SELECT result.

CREATE TEMP TABLE monthly_status_validation AS
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
;


WITH checks AS (
  SELECT
    COUNT(*) AS monthly_rows,
    COUNT(DISTINCT created_month) AS unique_months,
    MIN(created_month) AS first_month,
    MAX(created_month) AS latest_month,
    SUM(created_orders) AS monthly_order_total,
    COUNTIF(created_month >= DATE_TRUNC(CURRENT_DATE(), MONTH))
      AS incomplete_or_future_months,
    COUNTIF(created_orders != processing_orders + shipped_orders
      + complete_orders + cancelled_orders + returned_orders)
      AS status_count_mismatches,
    COUNTIF(currently_open_orders != processing_orders + shipped_orders)
      AS open_count_mismatches,
    COUNTIF(current_cancelled_share_pct IS DISTINCT FROM
      ROUND(SAFE_DIVIDE(cancelled_orders, created_orders) * 100, 2))
      AS cancelled_share_mismatches,
    COUNTIF(current_returned_share_pct IS DISTINCT FROM
      ROUND(SAFE_DIVIDE(returned_orders, created_orders) * 100, 2))
      AS returned_share_mismatches,
    COUNTIF(current_complete_share_pct IS DISTINCT FROM
      ROUND(SAFE_DIVIDE(complete_orders, created_orders) * 100, 2))
      AS complete_share_mismatches
  FROM monthly_status_validation
),
source_counts AS (
  SELECT COUNT(*) AS source_order_total
  FROM `bigquery-public-data.thelook_ecommerce.orders`
  WHERE created_at IS NOT NULL
    AND DATE(created_at) < DATE_TRUNC(CURRENT_DATE(), MONTH)
)
SELECT
  c.*,
  s.source_order_total,
  c.monthly_rows = c.unique_months AS one_row_per_month,
  c.monthly_rows = DATE_DIFF(c.latest_month, c.first_month, MONTH) + 1
    AS calendar_is_continuous,
  c.monthly_order_total = s.source_order_total AS orders_match_source
FROM checks AS c
CROSS JOIN source_counts AS s;

