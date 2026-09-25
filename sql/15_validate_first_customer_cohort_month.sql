-- Check why the first completed-purchase customer cohort appears in February
-- 2019, while the earlier revenue-growth validation began in January 2019.
-- The public source can change over time, so compare all three sources now.

WITH calendar_months AS (
  SELECT month
  FROM UNNEST(
    GENERATE_DATE_ARRAY(DATE '2019-01-01', DATE '2019-02-01', INTERVAL 1 MONTH)
  ) AS month
),

source_activity AS (
  SELECT
    DATE_TRUNC(DATE(delivered_at), MONTH) AS month,
    COUNT(*) AS completed_items,
    COUNT(DISTINCT order_id) AS completed_orders,
    COUNT(DISTINCT user_id) AS unique_buyers,
    COUNTIF(user_id IS NULL) AS missing_user_ids,
    ROUND(SUM(CAST(sale_price AS NUMERIC)), 2) AS recognized_revenue
  FROM `bigquery-public-data.thelook_ecommerce.order_items`
  WHERE status = 'Complete'
    AND delivered_at IS NOT NULL
    AND DATE(delivered_at) >= DATE '2019-01-01'
    AND DATE(delivered_at) < DATE '2019-03-01'
  GROUP BY month
)

SELECT
  c.month,
  COALESCE(s.completed_items, 0) AS source_completed_items,
  COALESCE(s.completed_orders, 0) AS source_completed_orders,
  COALESCE(s.unique_buyers, 0) AS source_unique_buyers,
  COALESCE(s.missing_user_ids, 0) AS source_missing_user_ids,
  COALESCE(s.recognized_revenue, 0) AS source_recognized_revenue,
  r.completed_items AS existing_view_completed_items,
  r.recognized_revenue AS existing_view_revenue,
  g.completed_items AS growth_view_completed_items,
  g.recognized_revenue AS growth_view_revenue
FROM calendar_months AS c
LEFT JOIN source_activity AS s
  ON c.month = s.month
LEFT JOIN `bigquery-analyst-practice.thelook_practice.monthly_revenue` AS r
  ON c.month = r.revenue_month
LEFT JOIN `bigquery-analyst-practice.thelook_practice.monthly_revenue_growth` AS g
  ON c.month = g.revenue_month
ORDER BY c.month;
