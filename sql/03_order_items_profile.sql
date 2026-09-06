-- Order items profile
-- Grain: one row per item within an order.

SELECT
  COUNT(*) AS order_item_rows,
  COUNT(DISTINCT id) AS unique_order_item_ids,
  COUNT(DISTINCT order_id) AS unique_orders,
  COUNT(DISTINCT product_id) AS unique_products,
  ROUND(SUM(CAST(sale_price AS NUMERIC)), 2) AS gross_item_value
FROM `bigquery-public-data.thelook_ecommerce.order_items`;