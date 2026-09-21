-- Deeper insights source-data audit
-- Sources: bigquery-public-data.thelook_ecommerce
-- Purpose: Confirm which fields and business events can support the V2
-- revenue, customer, category, and order-operations analyses.
--
-- This script is read-only. Run each numbered query separately while
-- reviewing its result and estimated bytes processed in BigQuery.


-- 1. Review the available columns and data types in the four core tables.
SELECT
  table_name,
  ordinal_position,
  column_name,
  data_type,
  is_nullable
FROM `bigquery-public-data.thelook_ecommerce.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name IN ('orders', 'order_items', 'products', 'users')
ORDER BY
  table_name,
  ordinal_position;


-- 2. Confirm the status values and volume in the order-level table.
SELECT
  status,
  COUNT(*) AS orders,
  ROUND(
    SAFE_DIVIDE(COUNT(*), SUM(COUNT(*)) OVER ()) * 100,
    2
  ) AS order_share_pct
FROM `bigquery-public-data.thelook_ecommerce.orders`
GROUP BY status
ORDER BY orders DESC;


-- 3. Confirm the status values and volume in the item-level table.
SELECT
  status,
  COUNT(*) AS order_items,
  COUNT(DISTINCT order_id) AS distinct_orders,
  ROUND(
    SAFE_DIVIDE(COUNT(*), SUM(COUNT(*)) OVER ()) * 100,
    2
  ) AS item_share_pct
FROM `bigquery-public-data.thelook_ecommerce.order_items`
GROUP BY status
ORDER BY order_items DESC;


-- 4. Check whether lifecycle timestamps are populated consistently by
-- item status. These results determine which operational durations and
-- rates can be calculated reliably.
SELECT
  status,
  COUNT(*) AS order_items,
  COUNTIF(created_at IS NULL) AS missing_created_at,
  COUNTIF(shipped_at IS NULL) AS missing_shipped_at,
  COUNTIF(delivered_at IS NULL) AS missing_delivered_at,
  COUNTIF(returned_at IS NULL) AS missing_returned_at,
  COUNTIF(shipped_at < created_at) AS shipped_before_created,
  COUNTIF(delivered_at < shipped_at) AS delivered_before_shipped,
  COUNTIF(returned_at < delivered_at) AS returned_before_delivered
FROM `bigquery-public-data.thelook_ecommerce.order_items`
GROUP BY status
ORDER BY order_items DESC;


-- 5. Review overall event-date coverage. The current incomplete month will
-- continue to be excluded from time-based reporting views.
SELECT
  MIN(DATE(created_at)) AS first_created_date,
  MAX(DATE(created_at)) AS latest_created_date,
  MIN(DATE(shipped_at)) AS first_shipped_date,
  MAX(DATE(shipped_at)) AS latest_shipped_date,
  MIN(DATE(delivered_at)) AS first_delivered_date,
  MAX(DATE(delivered_at)) AS latest_delivered_date,
  MIN(DATE(returned_at)) AS first_returned_date,
  MAX(DATE(returned_at)) AS latest_returned_date,
  DATE_TRUNC(CURRENT_DATE(), MONTH) AS current_month_start
FROM `bigquery-public-data.thelook_ecommerce.order_items`;


-- 5A. Quantify future-dated events and events in the current incomplete
-- month. These records must not enter completed-period operational trends.
SELECT
  COUNT(*) AS order_item_rows,
  COUNTIF(DATE(created_at) > CURRENT_DATE()) AS future_created_items,
  COUNTIF(DATE(shipped_at) > CURRENT_DATE()) AS future_shipped_items,
  COUNTIF(DATE(delivered_at) > CURRENT_DATE()) AS future_delivered_items,
  COUNTIF(DATE(returned_at) > CURRENT_DATE()) AS future_returned_items,
  COUNTIF(
    DATE(created_at) >= DATE_TRUNC(CURRENT_DATE(), MONTH)
  ) AS current_month_created_items,
  COUNTIF(
    DATE(shipped_at) >= DATE_TRUNC(CURRENT_DATE(), MONTH)
  ) AS current_month_shipped_items,
  COUNTIF(
    DATE(delivered_at) >= DATE_TRUNC(CURRENT_DATE(), MONTH)
  ) AS current_month_delivered_items,
  COUNTIF(
    DATE(returned_at) >= DATE_TRUNC(CURRENT_DATE(), MONTH)
  ) AS current_month_returned_items
FROM `bigquery-public-data.thelook_ecommerce.order_items`;


-- 6. Verify primary-key uniqueness and compare table grains.
SELECT
  (SELECT COUNT(*)
   FROM `bigquery-public-data.thelook_ecommerce.orders`) AS order_rows,
  (SELECT COUNT(DISTINCT order_id)
   FROM `bigquery-public-data.thelook_ecommerce.orders`) AS unique_order_ids,
  (SELECT COUNT(*)
   FROM `bigquery-public-data.thelook_ecommerce.order_items`) AS item_rows,
  (SELECT COUNT(DISTINCT id)
   FROM `bigquery-public-data.thelook_ecommerce.order_items`) AS unique_item_ids,
  (SELECT COUNT(*)
   FROM `bigquery-public-data.thelook_ecommerce.products`) AS product_rows,
  (SELECT COUNT(DISTINCT id)
   FROM `bigquery-public-data.thelook_ecommerce.products`) AS unique_product_ids,
  (SELECT COUNT(*)
   FROM `bigquery-public-data.thelook_ecommerce.users`) AS user_rows,
  (SELECT COUNT(DISTINCT id)
   FROM `bigquery-public-data.thelook_ecommerce.users`) AS unique_user_ids;


-- 7. Validate the relationships needed for customer, product, and
-- operational analysis.
SELECT
  COUNT(*) AS order_item_rows,
  COUNTIF(o.order_id IS NULL) AS items_without_order,
  COUNTIF(p.id IS NULL) AS items_without_product,
  COUNTIF(u.id IS NULL) AS items_without_user,
  COUNTIF(
    o.order_id IS NOT NULL
    AND oi.user_id != o.user_id
  ) AS item_order_user_mismatches,
  COUNTIF(
    o.order_id IS NOT NULL
    AND oi.status != o.status
  ) AS item_order_status_mismatches
FROM `bigquery-public-data.thelook_ecommerce.order_items` AS oi
LEFT JOIN `bigquery-public-data.thelook_ecommerce.orders` AS o
  ON oi.order_id = o.order_id
LEFT JOIN `bigquery-public-data.thelook_ecommerce.products` AS p
  ON oi.product_id = p.id
LEFT JOIN `bigquery-public-data.thelook_ecommerce.users` AS u
  ON oi.user_id = u.id;


-- 8. Check the price and cost fields before using them for revenue and
-- profitability analysis.
SELECT
  COUNT(*) AS order_item_rows,
  COUNTIF(oi.sale_price IS NULL) AS missing_sale_price,
  COUNTIF(oi.sale_price < 0) AS negative_sale_price,
  COUNTIF(p.cost IS NULL) AS missing_product_cost,
  COUNTIF(p.cost < 0) AS negative_product_cost,
  COUNTIF(
    p.cost IS NOT NULL
    AND oi.sale_price < p.cost
  ) AS items_sold_below_cost,
  ROUND(MIN(CAST(oi.sale_price AS NUMERIC)), 2) AS minimum_sale_price,
  ROUND(MAX(CAST(oi.sale_price AS NUMERIC)), 2) AS maximum_sale_price,
  ROUND(AVG(CAST(oi.sale_price AS NUMERIC)), 2) AS average_sale_price
FROM `bigquery-public-data.thelook_ecommerce.order_items` AS oi
LEFT JOIN `bigquery-public-data.thelook_ecommerce.products` AS p
  ON oi.product_id = p.id;


-- 8A. Profile the sale-price distribution and quantify unusually low or high
-- values before treating the full range as analytically meaningful.
SELECT
  COUNT(*) AS order_item_rows,
  COUNTIF(oi.sale_price < 1) AS items_below_one_dollar,
  COUNTIF(oi.sale_price < 5) AS items_below_five_dollars,
  COUNTIF(oi.sale_price > 500) AS items_above_five_hundred_dollars,
  COUNTIF(
    ABS(oi.sale_price - p.retail_price) > 0.01
  ) AS sale_retail_price_differences,
  ROUND(
    APPROX_QUANTILES(oi.sale_price, 100)[OFFSET(1)],
    2
  ) AS sale_price_p01,
  ROUND(
    APPROX_QUANTILES(oi.sale_price, 100)[OFFSET(50)],
    2
  ) AS sale_price_median,
  ROUND(
    APPROX_QUANTILES(oi.sale_price, 100)[OFFSET(99)],
    2
  ) AS sale_price_p99
FROM `bigquery-public-data.thelook_ecommerce.order_items` AS oi
INNER JOIN `bigquery-public-data.thelook_ecommerce.products` AS p
  ON oi.product_id = p.id;


-- 9. Compare the order-level item count with the number of item rows.
-- Any differences must be understood before order-level operational metrics
-- are added to the reporting layer.
WITH item_counts AS (
  SELECT
    order_id,
    COUNT(*) AS actual_item_rows
  FROM `bigquery-public-data.thelook_ecommerce.order_items`
  GROUP BY order_id
)

SELECT
  COUNT(*) AS joined_orders,
  COUNTIF(o.num_of_item = ic.actual_item_rows) AS matching_item_counts,
  COUNTIF(o.num_of_item != ic.actual_item_rows) AS mismatching_item_counts,
  MAX(ABS(o.num_of_item - ic.actual_item_rows)) AS largest_item_count_difference
FROM `bigquery-public-data.thelook_ecommerce.orders` AS o
INNER JOIN item_counts AS ic
  ON o.order_id = ic.order_id;


-- 10. Profile completed delivery months and identify any missing calendar
-- months. GENERATE_DATE_ARRAY creates the full expected monthly calendar.
WITH delivered_months AS (
  SELECT
    DATE_TRUNC(DATE(delivered_at), MONTH) AS delivery_month,
    COUNT(DISTINCT order_id) AS completed_orders,
    COUNT(*) AS completed_items,
    ROUND(SUM(CAST(sale_price AS NUMERIC)), 2) AS recognized_revenue
  FROM `bigquery-public-data.thelook_ecommerce.order_items`
  WHERE status = 'Complete'
    AND delivered_at IS NOT NULL
    AND DATE(delivered_at) < DATE_TRUNC(CURRENT_DATE(), MONTH)
  GROUP BY delivery_month
),

month_bounds AS (
  SELECT
    MIN(delivery_month) AS first_month,
    MAX(delivery_month) AS latest_month
  FROM delivered_months
),

calendar_months AS (
  SELECT month
  FROM month_bounds,
  UNNEST(
    GENERATE_DATE_ARRAY(first_month, latest_month, INTERVAL 1 MONTH)
  ) AS month
)

SELECT
  c.month,
  COALESCE(d.completed_orders, 0) AS completed_orders,
  COALESCE(d.completed_items, 0) AS completed_items,
  COALESCE(d.recognized_revenue, 0) AS recognized_revenue,
  d.delivery_month IS NULL AS is_missing_delivery_month
FROM calendar_months AS c
LEFT JOIN delivered_months AS d
  ON c.month = d.delivery_month
ORDER BY
  is_missing_delivery_month DESC,
  c.month;
