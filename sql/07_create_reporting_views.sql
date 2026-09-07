-- Create dashboard-ready reporting views.
-- Target dataset: bigquery-analyst-practice.thelook_practice
-- Running this script creates the views or replaces their definitions.

-- 1. Monthly revenue and month-over-month comparison.
CREATE OR REPLACE VIEW
  `bigquery-analyst-practice.thelook_practice.monthly_revenue` AS

WITH monthly_metrics AS (
  SELECT
    DATE_TRUNC(DATE(delivered_at), MONTH) AS revenue_month,
    COUNT(DISTINCT order_id) AS completed_orders,
    COUNT(*) AS completed_items,
    ROUND(
      SUM(CAST(sale_price AS NUMERIC)),
      2
    ) AS recognized_revenue,
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
  FROM monthly_metrics
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
FROM revenue_comparison;


-- 2. Category revenue, profitability, ranking, and contribution.
CREATE OR REPLACE VIEW
  `bigquery-analyst-practice.thelook_practice.category_performance` AS

WITH category_metrics AS (
  SELECT
    p.category,
    COUNT(DISTINCT oi.order_id) AS completed_orders,
    COUNT(*) AS completed_items,
    SUM(CAST(oi.sale_price AS NUMERIC))
      AS recognized_revenue,
    SUM(
      CAST(oi.sale_price AS NUMERIC)
      - CAST(p.cost AS NUMERIC)
    ) AS estimated_gross_profit
  FROM `bigquery-public-data.thelook_ecommerce.order_items` AS oi
  INNER JOIN `bigquery-public-data.thelook_ecommerce.products` AS p
    ON oi.product_id = p.id
  WHERE oi.status = 'Complete'
    AND oi.delivered_at IS NOT NULL
  GROUP BY p.category
)

SELECT
  category,
  RANK() OVER (
    ORDER BY recognized_revenue DESC
  ) AS revenue_rank,
  completed_orders,
  completed_items,
  ROUND(recognized_revenue, 2)
    AS recognized_revenue,
  ROUND(estimated_gross_profit, 2)
    AS estimated_gross_profit,
  ROUND(
    SAFE_DIVIDE(
      estimated_gross_profit,
      recognized_revenue
    ) * 100,
    2
  ) AS gross_margin_pct,
  ROUND(
    SAFE_DIVIDE(
      recognized_revenue,
      SUM(recognized_revenue) OVER ()
    ) * 100,
    2
  ) AS revenue_share_pct
FROM category_metrics;


-- 3. Customer segments based on completed-order behaviour.
CREATE OR REPLACE VIEW
  `bigquery-analyst-practice.thelook_practice.customer_segments` AS

WITH completed_orders AS (
  SELECT
    user_id,
    order_id,
    SUM(CAST(sale_price AS NUMERIC)) AS order_revenue
  FROM `bigquery-public-data.thelook_ecommerce.order_items`
  WHERE status = 'Complete'
    AND delivered_at IS NOT NULL
  GROUP BY
    user_id,
    order_id
),

customer_summary AS (
  SELECT
    u.id AS user_id,
    COUNT(co.order_id) AS completed_orders,
    COALESCE(
      SUM(co.order_revenue),
      0
    ) AS recognized_revenue
  FROM `bigquery-public-data.thelook_ecommerce.users` AS u
  LEFT JOIN completed_orders AS co
    ON u.id = co.user_id
  GROUP BY u.id
)

SELECT
  CASE
    WHEN completed_orders = 0 THEN 'No completed purchases'
    WHEN completed_orders = 1 THEN 'One-time customer'
    ELSE 'Repeat customer'
  END AS customer_segment,
  COUNT(*) AS customers,
  SUM(completed_orders) AS completed_orders,
  ROUND(
    SUM(recognized_revenue),
    2
  ) AS recognized_revenue,
  ROUND(
    AVG(completed_orders),
    2
  ) AS average_orders_per_customer,
  ROUND(
    AVG(recognized_revenue),
    2
  ) AS average_revenue_per_customer
FROM customer_summary
GROUP BY customer_segment;
