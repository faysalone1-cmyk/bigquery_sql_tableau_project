-- Orders overview
-- Source: bigquery-public-data.thelook_ecommerce.orders
-- Purpose: Confirm the table grain and summarize order activity.

-- Confirm that each row represents one order and review the date range.
SELECT
  COUNT(*) AS total_orders,
  COUNT(DISTINCT order_id) AS unique_order_ids,
  COUNT(DISTINCT user_id) AS unique_customers,
  SUM(num_of_item) AS total_items,
  MIN(created_at) AS first_order_at,
  MAX(created_at) AS latest_order_at
FROM `bigquery-public-data.thelook_ecommerce.orders`;

-- Count orders in each status.
SELECT
  status,
  COUNT(*) AS order_count
FROM `bigquery-public-data.thelook_ecommerce.orders`
GROUP BY status
ORDER BY order_count DESC;
