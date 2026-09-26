-- Phase 5: validate the deployed monthly_order_status view.
-- Read-only. Run after sql/28_create_monthly_order_status_view.sql.

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
  FROM `bigquery-analyst-practice.thelook_practice.monthly_order_status`
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
