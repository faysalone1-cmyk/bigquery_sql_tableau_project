-- Phase 4: deploy the product-performance reporting view.
-- Run only after sql/22_validate_product_performance.sql passes.
-- Grain: one row per sold product ID in completed calendar months.
-- Additive money fields are left unrounded so totals reconcile; format them
-- to two decimal places in reporting tools.

CREATE OR REPLACE VIEW
  `bigquery-analyst-practice.thelook_practice.product_performance` AS

WITH product_metrics AS (
  SELECT
    p.id AS product_id,
    p.name AS product_name,
    p.category,
    COUNT(DISTINCT oi.order_id) AS completed_orders,
    COUNT(*) AS completed_items,
    SUM(CAST(oi.sale_price AS NUMERIC)) AS recognized_revenue,
    SUM(CAST(p.cost AS NUMERIC)) AS estimated_product_cost,
    SUM(CAST(oi.sale_price AS NUMERIC) - CAST(p.cost AS NUMERIC))
      AS estimated_gross_profit
  FROM `bigquery-public-data.thelook_ecommerce.order_items` AS oi
  INNER JOIN `bigquery-public-data.thelook_ecommerce.products` AS p
    ON oi.product_id = p.id
  WHERE oi.status = 'Complete'
    AND oi.delivered_at IS NOT NULL
    AND DATE(oi.delivered_at) < DATE_TRUNC(CURRENT_DATE(), MONTH)
  GROUP BY p.id, p.name, p.category
),

ranked_products AS (
  SELECT
    *,
    RANK() OVER (
      ORDER BY recognized_revenue DESC
    ) AS overall_revenue_rank,
    RANK() OVER (
      PARTITION BY category ORDER BY recognized_revenue DESC
    ) AS category_revenue_rank,
    SUM(recognized_revenue) OVER () AS all_product_revenue,
    SUM(recognized_revenue) OVER (PARTITION BY category)
      AS category_revenue
  FROM product_metrics
)

SELECT
  product_id,
  product_name,
  category,
  overall_revenue_rank,
  category_revenue_rank,
  completed_orders,
  completed_items,
  recognized_revenue,
  estimated_product_cost,
  estimated_gross_profit,
  ROUND(
    SAFE_DIVIDE(estimated_gross_profit, recognized_revenue) * 100,
    2
  ) AS estimated_gross_margin_pct,
  ROUND(
    SAFE_DIVIDE(recognized_revenue, all_product_revenue) * 100,
    2
  ) AS total_revenue_share_pct,
  ROUND(
    SAFE_DIVIDE(recognized_revenue, category_revenue) * 100,
    2
  ) AS category_revenue_share_pct
FROM ranked_products;
