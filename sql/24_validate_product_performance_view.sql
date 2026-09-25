-- Phase 4: validate the deployed product-performance view.
-- Run after sql/23_create_product_performance_view.sql succeeds.

WITH source_totals AS (
  SELECT
    COUNT(*) AS source_items,
    COUNT(DISTINCT oi.product_id) AS source_products,
    ROUND(SUM(CAST(oi.sale_price AS NUMERIC)), 2) AS source_revenue,
    ROUND(SUM(
      CAST(oi.sale_price AS NUMERIC) - CAST(p.cost AS NUMERIC)
    ), 2) AS source_gross_profit
  FROM `bigquery-public-data.thelook_ecommerce.order_items` AS oi
  INNER JOIN `bigquery-public-data.thelook_ecommerce.products` AS p
    ON oi.product_id = p.id
  WHERE oi.status = 'Complete'
    AND oi.delivered_at IS NOT NULL
    AND DATE(oi.delivered_at) < DATE_TRUNC(CURRENT_DATE(), MONTH)
),

view_totals AS (
  SELECT
    COUNT(*) AS product_rows,
    COUNT(DISTINCT product_id) AS unique_products,
    COUNTIF(
      product_id IS NULL OR product_name IS NULL OR category IS NULL
    ) AS missing_product_attributes,
    COUNTIF(
      overall_revenue_rank < 1 OR category_revenue_rank < 1
    ) AS invalid_ranks,
    SUM(completed_items) AS product_items,
    ROUND(SUM(recognized_revenue), 2) AS product_revenue,
    ROUND(SUM(estimated_gross_profit), 2) AS product_gross_profit
  FROM `bigquery-analyst-practice.thelook_practice.product_performance`
),

category_comparison AS (
  SELECT
    COUNT(*) AS categories_compared,
    COUNTIF(
      p.category IS NULL OR c.category IS NULL
      OR p.completed_items != c.completed_items
      OR ABS(p.recognized_revenue - c.recognized_revenue) > 0.01
      OR ABS(p.estimated_gross_profit - c.estimated_gross_profit) > 0.01
    ) AS category_mismatches
  FROM (
    SELECT
      category,
      SUM(completed_items) AS completed_items,
      SUM(recognized_revenue) AS recognized_revenue,
      SUM(estimated_gross_profit) AS estimated_gross_profit
    FROM `bigquery-analyst-practice.thelook_practice.product_performance`
    GROUP BY category
  ) AS p
  FULL OUTER JOIN
    `bigquery-analyst-practice.thelook_practice.category_performance` AS c
    ON p.category = c.category
)

SELECT
  v.product_rows,
  v.unique_products,
  s.source_products,
  v.product_items,
  s.source_items,
  v.product_revenue,
  s.source_revenue,
  v.product_gross_profit,
  s.source_gross_profit,
  v.missing_product_attributes,
  v.invalid_ranks,
  c.categories_compared,
  c.category_mismatches,
  v.product_rows = v.unique_products AS one_row_per_product,
  v.product_rows = s.source_products
    AND v.product_items = s.source_items
    AND v.product_revenue = s.source_revenue
    AND v.product_gross_profit = s.source_gross_profit
    AS product_view_matches_source,
  c.category_mismatches = 0 AS categories_match_existing_view
FROM view_totals AS v
CROSS JOIN source_totals AS s
CROSS JOIN category_comparison AS c;
