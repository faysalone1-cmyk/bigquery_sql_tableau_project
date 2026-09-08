-- Category performance analysis
-- Join: order_items.product_id = products.id
-- Revenue rule: include only completed and delivered items.
-- Estimated gross profit: sale price minus product cost.

-- Validate the join before using it.
SELECT
  COUNT(*) AS joined_rows,
  COUNT(DISTINCT oi.id) AS unique_order_item_ids,
  COUNT(p.id) AS matched_product_rows,
  COUNTIF(p.id IS NULL) AS unmatched_product_rows
FROM `bigquery-public-data.thelook_ecommerce.order_items` AS oi
LEFT JOIN `bigquery-public-data.thelook_ecommerce.products` AS p
  ON oi.product_id = p.id;

-- Calculate, rank, and compare category performance.
WITH category_performance AS (
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
    AND DATE(oi.delivered_at) < DATE_TRUNC(CURRENT_DATE(), MONTH)
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
FROM category_performance
ORDER BY revenue_rank, category;
