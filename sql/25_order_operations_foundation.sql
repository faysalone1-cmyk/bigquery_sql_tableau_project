-- Phase 5: order-operations foundation check.
-- Read-only; run the whole query in BigQuery and review its one-row result.
-- Grain: one row per order. The rates below describe the CURRENT status of
-- orders created before this calendar month, not historical status at creation.
-- The denominator for each status rate is all eligible created orders,
-- including orders still Processing or Shipped.

WITH source_orders AS (
  SELECT
    order_id,
    status,
    created_at,
    shipped_at,
    delivered_at,
    returned_at
  FROM `bigquery-public-data.thelook_ecommerce.orders`
),

source_checks AS (
  SELECT
    COUNT(*) AS all_order_rows,
    COUNTIF(created_at IS NULL) AS missing_created_at,
    COUNTIF(DATE(created_at) >= DATE_TRUNC(CURRENT_DATE(), MONTH))
      AS current_or_future_created_orders,
    COUNTIF(DATE(created_at) > CURRENT_DATE()) AS future_created_orders
  FROM source_orders
),

eligible_orders AS (
  SELECT *
  FROM source_orders
  WHERE created_at IS NOT NULL
    AND DATE(created_at) < DATE_TRUNC(CURRENT_DATE(), MONTH)
),

eligible_checks AS (
  SELECT
    COUNT(*) AS eligible_orders,
    COUNT(DISTINCT order_id) AS unique_order_ids,
    MIN(DATE(created_at)) AS first_created_date,
    MAX(DATE(created_at)) AS latest_created_date,
    COUNTIF(status = 'Processing') AS processing_orders,
    COUNTIF(status = 'Shipped') AS shipped_orders,
    COUNTIF(status = 'Complete') AS complete_orders,
    COUNTIF(status = 'Cancelled') AS cancelled_orders,
    COUNTIF(status = 'Returned') AS returned_orders,
    COUNTIF(status IS NULL) AS missing_status,
    COUNTIF(status IS NOT NULL AND status NOT IN (
      'Processing', 'Shipped', 'Complete', 'Cancelled', 'Returned'
    )) AS unexpected_status,
    COUNTIF(status = 'Complete' AND delivered_at IS NULL)
      AS complete_without_delivery,
    COUNTIF(status = 'Returned' AND returned_at IS NULL)
      AS returned_without_return_date,
    COUNTIF(shipped_at < created_at) AS shipped_before_created,
    COUNTIF(delivered_at < shipped_at) AS delivered_before_shipped,
    COUNTIF(returned_at < delivered_at) AS returned_before_delivered,
    COUNTIF(DATE(shipped_at) > CURRENT_DATE()) AS future_shipped_orders,
    COUNTIF(DATE(delivered_at) > CURRENT_DATE()) AS future_delivered_orders,
    COUNTIF(DATE(returned_at) > CURRENT_DATE()) AS future_returned_orders
  FROM eligible_orders
)

SELECT
  s.*,
  e.*,
  e.eligible_orders = e.unique_order_ids AS one_row_per_order,
  e.eligible_orders = (
    e.processing_orders + e.shipped_orders + e.complete_orders
    + e.cancelled_orders + e.returned_orders
  ) AS known_statuses_cover_all_orders,
  ROUND(SAFE_DIVIDE(e.cancelled_orders, e.eligible_orders) * 100, 2)
    AS current_cancelled_share_pct,
  ROUND(SAFE_DIVIDE(e.returned_orders, e.eligible_orders) * 100, 2)
    AS current_returned_share_pct,
  ROUND(SAFE_DIVIDE(e.complete_orders, e.eligible_orders) * 100, 2)
    AS current_complete_share_pct
FROM source_checks AS s
CROSS JOIN eligible_checks AS e;
    