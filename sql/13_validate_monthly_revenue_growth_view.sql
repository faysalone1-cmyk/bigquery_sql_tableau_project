-- Validate the deployed monthly_revenue_growth view.
-- Expected result: all three Boolean checks are TRUE.

WITH deployed_view AS (
  SELECT
    COUNT(*) AS monthly_rows,
    COUNT(DISTINCT revenue_month) AS unique_months,
    MIN(revenue_month) AS first_month,
    MAX(revenue_month) AS latest_month,
    SUM(completed_orders) AS completed_orders,
    SUM(completed_items) AS completed_items,
    ROUND(SUM(recognized_revenue), 2) AS recognized_revenue
  FROM `bigquery-analyst-practice.thelook_practice.monthly_revenue_growth`
),

existing_view AS (
  SELECT
    SUM(completed_orders) AS completed_orders,
    SUM(completed_items) AS completed_items,
    ROUND(SUM(recognized_revenue), 2) AS recognized_revenue
  FROM `bigquery-analyst-practice.thelook_practice.monthly_revenue`
)

SELECT
  d.monthly_rows,
  d.unique_months,
  d.first_month,
  d.latest_month,
  d.monthly_rows = d.unique_months AS one_row_per_month,
  d.monthly_rows = DATE_DIFF(
    d.latest_month,
    d.first_month,
    MONTH
  ) + 1 AS calendar_is_continuous,
  d.latest_month < DATE_TRUNC(CURRENT_DATE(), MONTH)
    AS latest_month_is_complete,
  d.completed_orders,
  d.completed_items,
  d.recognized_revenue,
  d.completed_orders = e.completed_orders AS completed_orders_match,
  d.completed_items = e.completed_items AS completed_items_match,
  d.recognized_revenue = e.recognized_revenue AS recognized_revenue_matches
FROM deployed_view AS d
CROSS JOIN existing_view AS e;
