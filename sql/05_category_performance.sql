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

-- Calculate category performance.
SELECT
  p.category,
  COUNT(DISTINCT oi.order_id) AS completed_orders,
  COUNT(*) AS completed_items,
  ROUND(
    SUM(CAST(oi.sale_price AS NUMERIC)),
    2
  ) AS recognized_revenue,
  ROUND(
    SUM(
      CAST(oi.sale_price AS NUMERIC)
      - CAST(p.cost AS NUMERIC)
    ),
    2
  ) AS estimated_gross_profit,
  ROUND(
    SAFE_DIVIDE(
      SUM(
        CAST(oi.sale_price AS NUMERIC)
        - CAST(p.cost AS NUMERIC)
      ),
      SUM(CAST(oi.sale_price AS NUMERIC))
    ) * 100,
    2
  ) AS gross_margin_pct
FROM `bigquery-public-data.thelook_ecommerce.order_items` AS oi
INNER JOIN `bigquery-public-data.thelook_ecommerce.products` AS p
  ON oi.product_id = p.id
WHERE oi.status = 'Complete'
  AND oi.delivered_at IS NOT NULL
GROUP BY p.category
ORDER BY recognized_revenue DESC;