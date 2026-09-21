-- Validate the monthly revenue growth analysis before creating its view.
--
-- This BigQuery script creates a temporary table for the current session only.
-- It does not create or change any permanent reporting object.

CREATE TEMP TABLE monthly_growth_validation AS

WITH monthly_metrics AS (
  SELECT
    DATE_TRUNC(DATE(delivered_at), MONTH) AS revenue_month,
    COUNT(DISTINCT order_id) AS completed_orders,
    COUNT(*) AS completed_items,
    SUM(CAST(sale_price AS NUMERIC)) AS recognized_revenue
  FROM `bigquery-public-data.thelook_ecommerce.order_items`
  WHERE status = 'Complete'
    AND delivered_at IS NOT NULL
    AND DATE(delivered_at) < DATE_TRUNC(CURRENT_DATE(), MONTH)
  GROUP BY revenue_month
),

month_bounds AS (
  SELECT
    MIN(revenue_month) AS first_month,
    MAX(revenue_month) AS latest_month
  FROM monthly_metrics
),

calendar_months AS (
  SELECT month AS revenue_month
  FROM month_bounds,
  UNNEST(
    GENERATE_DATE_ARRAY(first_month, latest_month, INTERVAL 1 MONTH)
  ) AS month
),

monthly_series AS (
  SELECT
    c.revenue_month,
    COALESCE(m.completed_orders, 0) AS completed_orders,
    COALESCE(m.completed_items, 0) AS completed_items,
    COALESCE(
      m.recognized_revenue,
      CAST(0 AS NUMERIC)
    ) AS recognized_revenue
  FROM calendar_months AS c
  LEFT JOIN monthly_metrics AS m
    ON c.revenue_month = m.revenue_month
),

window_metrics AS (
  SELECT
    *,
    LAG(recognized_revenue, 1) OVER (
      ORDER BY revenue_month
    ) AS previous_month_revenue,
    LAG(recognized_revenue, 12) OVER (
      ORDER BY revenue_month
    ) AS previous_year_revenue,
    COUNT(*) OVER (
      ORDER BY revenue_month
      ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS rolling_3_month_count,
    SUM(recognized_revenue) OVER (
      ORDER BY revenue_month
      ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS rolling_3_month_revenue_raw,
    COUNT(*) OVER (
      ORDER BY revenue_month
      ROWS BETWEEN 11 PRECEDING AND CURRENT ROW
    ) AS rolling_12_month_count,
    SUM(recognized_revenue) OVER (
      ORDER BY revenue_month
      ROWS BETWEEN 11 PRECEDING AND CURRENT ROW
    ) AS rolling_12_month_revenue_raw
  FROM monthly_series
)

SELECT
  revenue_month,
  completed_orders,
  completed_items,
  ROUND(recognized_revenue, 2) AS recognized_revenue,
  ROUND(
    SAFE_DIVIDE(recognized_revenue, completed_orders),
    2
  ) AS average_order_value,
  ROUND(previous_month_revenue, 2) AS previous_month_revenue,
  ROUND(
    recognized_revenue - previous_month_revenue,
    2
  ) AS month_over_month_revenue_change,
  ROUND(
    SAFE_DIVIDE(
      recognized_revenue - previous_month_revenue,
      previous_month_revenue
    ) * 100,
    2
  ) AS month_over_month_growth_pct,
  ROUND(previous_year_revenue, 2) AS previous_year_revenue,
  ROUND(
    recognized_revenue - previous_year_revenue,
    2
  ) AS year_over_year_revenue_change,
  ROUND(
    SAFE_DIVIDE(
      recognized_revenue - previous_year_revenue,
      previous_year_revenue
    ) * 100,
    2
  ) AS year_over_year_growth_pct,
  IF(
    rolling_3_month_count = 3,
    ROUND(rolling_3_month_revenue_raw, 2),
    NULL
  ) AS rolling_3_month_revenue,
  IF(
    rolling_3_month_count = 3,
    ROUND(SAFE_DIVIDE(rolling_3_month_revenue_raw, 3), 2),
    NULL
  ) AS rolling_3_month_average_revenue,
  IF(
    rolling_12_month_count = 12,
    ROUND(rolling_12_month_revenue_raw, 2),
    NULL
  ) AS rolling_12_month_revenue,
  IF(
    rolling_12_month_count = 12,
    ROUND(SAFE_DIVIDE(rolling_12_month_revenue_raw, 12), 2),
    NULL
  ) AS rolling_12_month_average_revenue
FROM window_metrics;


-- 1. Validate grain, calendar continuity, complete-month coverage, and the
-- expected locations of NULL comparison and rolling-window values.
SELECT
  COUNT(*) AS monthly_rows,
  COUNT(DISTINCT revenue_month) AS unique_months,
  MIN(revenue_month) AS first_month,
  MAX(revenue_month) AS latest_month,
  DATE_DIFF(
    MAX(revenue_month),
    MIN(revenue_month),
    MONTH
  ) + 1 AS expected_calendar_months,
  COUNT(*) = COUNT(DISTINCT revenue_month) AS one_row_per_month,
  COUNT(*) = DATE_DIFF(
    MAX(revenue_month),
    MIN(revenue_month),
    MONTH
  ) + 1 AS calendar_is_continuous,
  MAX(revenue_month) < DATE_TRUNC(CURRENT_DATE(), MONTH)
    AS latest_month_is_complete,
  COUNTIF(previous_month_revenue IS NULL) AS null_previous_month_rows,
  COUNTIF(previous_year_revenue IS NULL) AS null_previous_year_rows,
  COUNTIF(rolling_3_month_revenue IS NULL) AS null_rolling_3_rows,
  COUNTIF(rolling_12_month_revenue IS NULL) AS null_rolling_12_rows
FROM monthly_growth_validation;


-- 2. Reconcile the new analysis with the existing monthly revenue view.
WITH existing_view AS (
  SELECT
    SUM(completed_orders) AS completed_orders,
    SUM(completed_items) AS completed_items,
    ROUND(SUM(recognized_revenue), 2) AS recognized_revenue
  FROM `bigquery-analyst-practice.thelook_practice.monthly_revenue`
),

growth_analysis AS (
  SELECT
    SUM(completed_orders) AS completed_orders,
    SUM(completed_items) AS completed_items,
    ROUND(SUM(recognized_revenue), 2) AS recognized_revenue
  FROM monthly_growth_validation
)

SELECT
  e.completed_orders AS existing_completed_orders,
  g.completed_orders AS growth_completed_orders,
  e.completed_orders = g.completed_orders AS completed_orders_match,
  e.completed_items AS existing_completed_items,
  g.completed_items AS growth_completed_items,
  e.completed_items = g.completed_items AS completed_items_match,
  e.recognized_revenue AS existing_recognized_revenue,
  g.recognized_revenue AS growth_recognized_revenue,
  e.recognized_revenue = g.recognized_revenue AS recognized_revenue_matches
FROM existing_view AS e
CROSS JOIN growth_analysis AS g;


-- 3. Independently recalculate AOV, MoM, and YoY arithmetic and count any
-- differences greater than one cent or 0.01 percentage points.
SELECT
  COUNTIF(
    ABS(
      average_order_value
      - ROUND(SAFE_DIVIDE(recognized_revenue, completed_orders), 2)
    ) > 0.01
  ) AS average_order_value_mismatches,
  COUNTIF(
    previous_month_revenue IS NOT NULL
    AND ABS(
      month_over_month_revenue_change
      - ROUND(recognized_revenue - previous_month_revenue, 2)
    ) > 0.01
  ) AS month_over_month_change_mismatches,
  COUNTIF(
    previous_month_revenue IS NOT NULL
    AND ABS(
      month_over_month_growth_pct
      - ROUND(
        SAFE_DIVIDE(
          recognized_revenue - previous_month_revenue,
          previous_month_revenue
        ) * 100,
        2
      )
    ) > 0.01
  ) AS month_over_month_growth_mismatches,
  COUNTIF(
    previous_year_revenue IS NOT NULL
    AND ABS(
      year_over_year_revenue_change
      - ROUND(recognized_revenue - previous_year_revenue, 2)
    ) > 0.01
  ) AS year_over_year_change_mismatches,
  COUNTIF(
    previous_year_revenue IS NOT NULL
    AND ABS(
      year_over_year_growth_pct
      - ROUND(
        SAFE_DIVIDE(
          recognized_revenue - previous_year_revenue,
          previous_year_revenue
        ) * 100,
        2
      )
    ) > 0.01
  ) AS year_over_year_growth_mismatches
FROM monthly_growth_validation;


-- 4. Independently rebuild the 3- and 12-month windows through self-joins.
WITH rolling_3_check AS (
  SELECT
    current_month.revenue_month,
    COUNT(history.revenue_month) AS months_in_window,
    ROUND(SUM(history.recognized_revenue), 2) AS revenue_in_window
  FROM monthly_growth_validation AS current_month
  LEFT JOIN monthly_growth_validation AS history
    ON history.revenue_month BETWEEN
      DATE_SUB(current_month.revenue_month, INTERVAL 2 MONTH)
      AND current_month.revenue_month
  GROUP BY current_month.revenue_month
),

rolling_12_check AS (
  SELECT
    current_month.revenue_month,
    COUNT(history.revenue_month) AS months_in_window,
    ROUND(SUM(history.recognized_revenue), 2) AS revenue_in_window
  FROM monthly_growth_validation AS current_month
  LEFT JOIN monthly_growth_validation AS history
    ON history.revenue_month BETWEEN
      DATE_SUB(current_month.revenue_month, INTERVAL 11 MONTH)
      AND current_month.revenue_month
  GROUP BY current_month.revenue_month
)

SELECT
  COUNTIF(
    CASE
      WHEN r3.months_in_window = 3
        THEN ABS(g.rolling_3_month_revenue - r3.revenue_in_window) > 0.01
      ELSE g.rolling_3_month_revenue IS NOT NULL
    END
  ) AS rolling_3_revenue_mismatches,
  COUNTIF(
    CASE
      WHEN r3.months_in_window = 3
        THEN ABS(
          g.rolling_3_month_average_revenue
          - ROUND(SAFE_DIVIDE(r3.revenue_in_window, 3), 2)
        ) > 0.01
      ELSE g.rolling_3_month_average_revenue IS NOT NULL
    END
  ) AS rolling_3_average_mismatches,
  COUNTIF(
    CASE
      WHEN r12.months_in_window = 12
        THEN ABS(g.rolling_12_month_revenue - r12.revenue_in_window) > 0.01
      ELSE g.rolling_12_month_revenue IS NOT NULL
    END
  ) AS rolling_12_revenue_mismatches,
  COUNTIF(
    CASE
      WHEN r12.months_in_window = 12
        THEN ABS(
          g.rolling_12_month_average_revenue
          - ROUND(SAFE_DIVIDE(r12.revenue_in_window, 12), 2)
        ) > 0.01
      ELSE g.rolling_12_month_average_revenue IS NOT NULL
    END
  ) AS rolling_12_average_mismatches
FROM monthly_growth_validation AS g
INNER JOIN rolling_3_check AS r3
  ON g.revenue_month = r3.revenue_month
INNER JOIN rolling_12_check AS r12
  ON g.revenue_month = r12.revenue_month;
