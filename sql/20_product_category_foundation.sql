-- Phase 4: product and category foundation check.
-- Read-only. Run this query in BigQuery before building product-level views.
-- The public source can change, so compare all totals in the same run.

WITH completed_items AS (
  SELECT
    oi.id AS order_item_id,
    oi.order_id,
    oi.product_id,
    CAST(oi.sale_price AS NUMERIC) AS sale_price,
    p.id AS matched_product_id,
    p.category,
    p.name AS product_name,
    CAST(p.cost AS NUMERIC) AS product_cost
  FROM `bigquery-public-data.thelook_ecommerce.order_items` AS oi
  LEFT JOIN `bigquery-public-data.thelook_ecommerce.products` AS p
    ON oi.product_id = p.id
  WHERE oi.status = 'Complete'
    AND oi.delivered_at IS NOT NULL
    AND DATE(oi.delivered_at) < DATE_TRUNC(CURRENT_DATE(), MONTH)
),

source_totals AS (
  SELECT
    COUNT(*) AS completed_item_rows,
    COUNT(DISTINCT order_item_id) AS unique_completed_item_ids,
    COUNTIF(matched_product_id IS NULL) AS unmatched_product_rows,
    COUNTIF(category IS NULL OR TRIM(category) = '') AS missing_category_rows,
    COUNTIF(product_name IS NULL OR TRIM(product_name) = '') AS missing_product_name_rows,
    COUNTIF(product_cost IS NULL) AS missing_product_cost_rows,
    COUNTIF(product_cost < 0) AS negative_product_cost_rows,
    COUNTIF(sale_price IS NULL) AS missing_sale_price_rows,
    COUNTIF(sale_price < 0) AS negative_sale_price_rows,
    COUNT(DISTINCT category) AS categories,
    COUNT(DISTINCT product_id) AS products_sold,
    ROUND(SUM(sale_price), 2) AS source_recognized_revenue,
    ROUND(SUM(sale_price - product_cost), 2) AS source_estimated_gross_profit
  FROM completed_items
),

monthly_view_totals AS (
  SELECT
    SUM(completed_items) AS monthly_view_items,
    ROUND(SUM(recognized_revenue), 2) AS monthly_view_revenue
  FROM `bigquery-analyst-practice.thelook_practice.monthly_revenue`
),

category_view_totals AS (
  SELECT
    SUM(completed_items) AS category_view_items,
    ROUND(SUM(recognized_revenue), 2) AS category_view_revenue,
    ROUND(SUM(estimated_gross_profit), 2) AS category_view_estimated_gross_profit
  FROM `bigquery-analyst-practice.thelook_practice.category_performance`
)

SELECT
  s.*,
  m.monthly_view_items,
  m.monthly_view_revenue,
  c.category_view_items,
  c.category_view_revenue,
  c.category_view_estimated_gross_profit,
  s.completed_item_rows = s.unique_completed_item_ids AS one_row_per_item,
  s.completed_item_rows = m.monthly_view_items
    AND ABS(s.source_recognized_revenue - m.monthly_view_revenue) <= 0.05
    AS monthly_view_matches_source,
  s.completed_item_rows = c.category_view_items
    AND ABS(s.source_recognized_revenue - c.category_view_revenue) <= 0.05
    AND ABS(
      s.source_estimated_gross_profit - c.category_view_estimated_gross_profit
    ) <= 0.05
    AS category_view_matches_source
FROM source_totals AS s
CROSS JOIN monthly_view_totals AS m
CROSS JOIN category_view_totals AS c;
