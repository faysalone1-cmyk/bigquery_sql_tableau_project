-- Phase 5: check order-level delivery and return durations before reporting.
-- Read-only. Returns two rows, one for each duration being assessed.
-- Delivery timing includes Complete and Returned orders: both were delivered.
-- Return timing includes only Returned orders.
-- Use completed END-EVENT months, not order creation months.
-- Every candidate is assigned one mutually exclusive quality outcome.
-- This is elapsed calendar time, not business days or an SLA assessment.

WITH event_pairs AS (
  SELECT
    'shipping_to_delivery' AS duration_type,
    order_id,
    shipped_at AS start_at,
    delivered_at AS end_at
  FROM `bigquery-public-data.thelook_ecommerce.orders`
  WHERE status IN ('Complete', 'Returned')

  UNION ALL

  SELECT
    'delivery_to_return' AS duration_type,
    order_id,
    delivered_at AS start_at,
    returned_at AS end_at
  FROM `bigquery-public-data.thelook_ecommerce.orders`
  WHERE status = 'Returned'
),

classified AS (
  SELECT
    *,
    CASE
      WHEN end_at IS NULL THEN 'missing_end'
      WHEN DATE(end_at) >= DATE_TRUNC(CURRENT_DATE(), MONTH)
        THEN 'incomplete_or_future_end_month'
      WHEN start_at IS NULL THEN 'missing_start'
      WHEN end_at < start_at THEN 'reversed_timestamps'
      ELSE 'valid'
    END AS quality_outcome
  FROM event_pairs
),

durations AS (
  SELECT
    *,
    IF(
      quality_outcome = 'valid',
      TIMESTAMP_DIFF(end_at, start_at, SECOND) / 86400.0,
      NULL
    ) AS elapsed_days
  FROM classified
)

SELECT
  duration_type,
  COUNT(*) AS candidate_orders,
  COUNT(DISTINCT order_id) AS unique_candidate_order_ids,
  COUNTIF(quality_outcome = 'missing_end') AS missing_end_orders,
  COUNTIF(quality_outcome = 'incomplete_or_future_end_month')
    AS incomplete_or_future_end_month_orders,
  COUNTIF(quality_outcome = 'missing_start') AS missing_start_orders,
  COUNTIF(quality_outcome = 'reversed_timestamps') AS reversed_timestamp_orders,
  COUNTIF(quality_outcome = 'valid') AS valid_duration_orders,
  COUNTIF(quality_outcome = 'valid' AND elapsed_days = 0)
    AS zero_duration_orders,
  MIN(IF(quality_outcome = 'valid', DATE(end_at), NULL)) AS first_valid_end_date,
  MAX(IF(quality_outcome = 'valid', DATE(end_at), NULL)) AS latest_valid_end_date,
  ROUND(MIN(elapsed_days), 2) AS minimum_days,
  ROUND(AVG(elapsed_days), 2) AS average_days,
  ROUND(APPROX_QUANTILES(elapsed_days, 100)[SAFE_OFFSET(50)], 2)
    AS approximate_median_days,
  ROUND(APPROX_QUANTILES(elapsed_days, 100)[SAFE_OFFSET(90)], 2)
    AS approximate_p90_days,
  ROUND(MAX(elapsed_days), 2) AS maximum_days,
  COUNT(*) = COUNT(DISTINCT order_id) AS one_row_per_candidate_order,
  COUNT(*) = (
    COUNTIF(quality_outcome = 'missing_end')
    + COUNTIF(quality_outcome = 'incomplete_or_future_end_month')
    + COUNTIF(quality_outcome = 'missing_start')
    + COUNTIF(quality_outcome = 'reversed_timestamps')
    + COUNTIF(quality_outcome = 'valid')
  ) AS all_candidates_accounted_for
FROM durations
GROUP BY duration_type
ORDER BY duration_type;
