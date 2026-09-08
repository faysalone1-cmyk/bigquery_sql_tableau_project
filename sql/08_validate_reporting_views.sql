-- Validate that the reporting views use the same completed-month period
-- and reconcile their shared orders, items, revenue, and customer totals.
--
-- Category order counts are not compared because one order may contain
-- products from multiple categories.

WITH monthly_check AS (
  SELECT
    MAX(revenue_month) AS latest_reported_month,
    SUM(completed_orders) AS monthly_orders,
    SUM(completed_items) AS monthly_items,
    ROUND(SUM(recognized_revenue), 2) AS monthly_revenue
  FROM `bigquery-analyst-practice.thelook_practice.monthly_revenue`
),

category_check AS (
  SELECT
    SUM(completed_items) AS category_items,
    ROUND(SUM(recognized_revenue), 2) AS category_revenue
  FROM `bigquery-analyst-practice.thelook_practice.category_performance`
),

customer_check AS (
  SELECT
    SUM(customers) AS customer_count,
    SUM(completed_orders) AS customer_orders,
    ROUND(SUM(recognized_revenue), 2) AS customer_revenue
  FROM `bigquery-analyst-practice.thelook_practice.customer_segments`
)

SELECT
  latest_reported_month,
  latest_reported_month < DATE_TRUNC(CURRENT_DATE(), MONTH)
    AS latest_month_is_complete,

  monthly_orders,
  customer_orders,
  monthly_orders = customer_orders AS orders_match,

  monthly_items,
  category_items,
  monthly_items = category_items AS items_match,

  monthly_revenue,
  category_revenue,
  monthly_revenue = category_revenue
    AS category_revenue_matches,

  customer_revenue,
  monthly_revenue = customer_revenue
    AS customer_revenue_matches,

  customer_count
FROM monthly_check
CROSS JOIN category_check
CROSS JOIN customer_check;
