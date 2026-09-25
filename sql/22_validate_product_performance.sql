-- Phase 4: validate the full product-level result before creating a view.
-- Read-only. The top-50 preview in sql/21_product_performance.sql cannot
-- be used for whole-business reconciliation.

WITH completed_items AS (
  SELECT
    oi.id AS order_item_id,
    oi.order_id,
    p.id AS product_id,
    p.category,
    CAST(oi.sale_price AS NUMERIC) AS sale_price,
    CAST(p.cost AS NUMERIC) AS product_cost
  FROM `bigquery-public-data.thelook_ecommerce.order_items` AS oi
  INNER JOIN `bigquery-public-data.thelook_ecommerce.products` AS p
    ON oi.product_id = p.id
  WHERE oi.status = 'Complete'
    AND oi.delivered_at IS NOT NULL
    AND DATE(oi.delivered_at) < DATE_TRUNC(CURRENT_DATE(), MONTH)
),

product_metrics AS (
  SELECT
    product_id,
    category,
    COUNT(*) AS completed_items,
    SUM(sale_price) AS recognized_revenue,
    SUM(sale_price - product_cost) AS estimated_gross_profit
  FROM completed_items
  GROUP BY product_id, category
),

product_totals AS (
  SELECT
    COUNT(*) AS product_rows,
    COUNT(DISTINCT product_id) AS unique_products,
    SUM(completed_items) AS product_items,
    ROUND(SUM(recognized_revenue), 2) AS product_revenue,
    ROUND(SUM(estimated_gross_profit), 2) AS product_gross_profit
  FROM product_metrics
),

source_totals AS (
  SELECT
    COUNT(*) AS source_items,
    COUNT(DISTINCT product_id) AS source_products,
    ROUND(SUM(sale_price), 2) AS source_revenue,
    ROUND(SUM(sale_price - product_cost), 2) AS source_gross_profit
  FROM completed_items
),

category_comparison AS (
  SELECT
    COUNT(*) AS categories_compared,
    COUNTIF(
      p.category IS NULL OR v.category IS NULL
      OR p.completed_items != v.completed_items
      OR ABS(p.recognized_revenue - v.recognized_revenue) > 0.01
      OR ABS(p.estimated_gross_profit - v.estimated_gross_profit) > 0.01
    ) AS category_mismatches
  FROM (
    SELECT
      category,
      SUM(completed_items) AS completed_items,
      SUM(recognized_revenue) AS recognized_revenue,
      SUM(estimated_gross_profit) AS estimated_gross_profit
    FROM product_metrics
    GROUP BY category
  ) AS p
  FULL OUTER JOIN
    `bigquery-analyst-practice.thelook_practice.category_performance` AS v
    ON p.category = v.category
)

SELECT
  p.product_rows,
  p.unique_products,
  s.source_products,
  p.product_items,
  s.source_items,
  p.product_revenue,
  s.source_revenue,
  p.product_gross_profit,
  s.source_gross_profit,
  c.categories_compared,
  c.category_mismatches,
  p.product_rows = p.unique_products AS one_row_per_product,
  p.product_rows = s.source_products
    AND p.product_items = s.source_items
    AND p.product_revenue = s.source_revenue
    AND p.product_gross_profit = s.source_gross_profit
    AS product_totals_match_source,
  c.category_mismatches = 0 AS categories_match_existing_view
FROM product_totals AS p
CROSS JOIN source_totals AS s
CROSS JOIN category_comparison AS c;
