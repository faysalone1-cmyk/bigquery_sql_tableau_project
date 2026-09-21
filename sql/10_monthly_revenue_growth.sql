-- Monthly revenue growth analysis
-- Grain: one row per completed calendar month.
--
-- Business rules:
-- - Recognized revenue includes only order items with status = 'Complete'.
-- - A non-null delivery timestamp is required.
-- - Revenue is assigned to the delivery month.
-- - The current incomplete calendar month is excluded.
-- - A generated calendar preserves monthly continuity for window functions.
-- - Rolling metrics are NULL until a complete 3- or 12-month window exists.

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
    ROUND(
      SAFE_DIVIDE(rolling_3_month_revenue_raw, 3),
      2
    ),
    NULL
  ) AS rolling_3_month_average_revenue,

  IF(
    rolling_12_month_count = 12,
    ROUND(rolling_12_month_revenue_raw, 2),
    NULL
  ) AS rolling_12_month_revenue,
  IF(
    rolling_12_month_count = 12,
    ROUND(
      SAFE_DIVIDE(rolling_12_month_revenue_raw, 12),
      2
    ),
    NULL
  ) AS rolling_12_month_average_revenue
FROM window_metrics
ORDER BY revenue_month;
