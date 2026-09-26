-- Phase 5: validate monthly order-duration output against current source.
-- Run the entire script and open the final SELECT result (two rows).
-- Creates only a temporary table; no permanent reporting objects are changed.
-- Percentiles are checked for valid bounds, not exact statistical accuracy.
-- A tiny elapsed-total tolerance handles FLOAT64 aggregation differences.

CREATE TEMP TABLE monthly_duration_validation AS
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
  DATE_TRUNC(DATE(end_at), MONTH) AS event_month,
  COUNT(*) AS ended_orders,
  COUNTIF(quality_outcome = 'valid') AS valid_duration_orders,
  COUNTIF(quality_outcome = 'missing_start') AS missing_start_orders,
  COUNTIF(quality_outcome = 'reversed_timestamps') AS reversed_timestamp_orders,
  COUNTIF(quality_outcome = 'valid' AND elapsed_days = 0)
    AS zero_duration_orders,
  ROUND(SAFE_DIVIDE(COUNTIF(quality_outcome = 'valid'), COUNT(*)) * 100, 2)
    AS valid_duration_share_pct,
  SUM(elapsed_days) AS total_elapsed_days,
  ROUND(AVG(elapsed_days), 2) AS average_days,
  ROUND(APPROX_QUANTILES(elapsed_days, 100)[SAFE_OFFSET(50)], 2)
    AS approximate_median_days,
  ROUND(APPROX_QUANTILES(elapsed_days, 100)[SAFE_OFFSET(90)], 2)
    AS approximate_p90_days,
  ROUND(MAX(elapsed_days), 2) AS maximum_days
FROM durations
WHERE end_at IS NOT NULL
  AND DATE(end_at) < DATE_TRUNC(CURRENT_DATE(), MONTH)
GROUP BY duration_type, event_month
;


WITH source_events AS (
  SELECT 'shipping_to_delivery' AS duration_type,
    shipped_at AS start_at, delivered_at AS end_at
  FROM `bigquery-public-data.thelook_ecommerce.orders`
  WHERE status IN ('Complete', 'Returned')
  UNION ALL
  SELECT 'delivery_to_return', delivered_at, returned_at
  FROM `bigquery-public-data.thelook_ecommerce.orders`
  WHERE status = 'Returned'
),
source_months AS (
  SELECT
    duration_type,
    DATE_TRUNC(DATE(end_at), MONTH) AS event_month,
    COUNT(*) AS source_ended_orders,
    COUNTIF(start_at IS NOT NULL AND start_at <= end_at) AS source_valid_orders,
    SUM(IF(start_at IS NOT NULL AND start_at <= end_at,
      TIMESTAMP_DIFF(end_at, start_at, SECOND) / 86400.0, NULL))
      AS source_elapsed_days
  FROM source_events
  WHERE end_at IS NOT NULL
    AND DATE(end_at) < DATE_TRUNC(CURRENT_DATE(), MONTH)
  GROUP BY duration_type, event_month
),
compared AS (
  SELECT
    COALESCE(m.duration_type, s.duration_type) AS duration_type,
    m.event_month,
    s.event_month AS source_event_month,
    m.ended_orders,
    m.valid_duration_orders,
    s.source_ended_orders,
    s.source_valid_orders,
    m.missing_start_orders,
    m.reversed_timestamp_orders,
    m.zero_duration_orders,
    m.valid_duration_share_pct,
    m.average_days,
    m.total_elapsed_days,
    s.source_elapsed_days,
    m.approximate_median_days,
    m.approximate_p90_days,
    m.maximum_days
  FROM monthly_duration_validation AS m
  FULL OUTER JOIN source_months AS s
    ON m.duration_type = s.duration_type AND m.event_month = s.event_month
)
SELECT
  duration_type,
  COUNT(*) AS compared_month_rows,
  COUNT(DISTINCT event_month) AS unique_output_months,
  MIN(event_month) AS first_event_month,
  MAX(event_month) AS latest_event_month,
  SUM(valid_duration_orders) AS output_valid_orders,
  SUM(source_valid_orders) AS source_valid_orders,
  COUNTIF(event_month IS NULL OR source_event_month IS NULL)
    AS missing_or_extra_months,
  COUNT(*) - COUNT(DISTINCT event_month) AS duplicate_or_missing_month_rows,
  COUNTIF(event_month >= DATE_TRUNC(CURRENT_DATE(), MONTH))
    AS incomplete_or_future_months,
  COUNTIF(ended_orders IS DISTINCT FROM source_ended_orders
    OR valid_duration_orders IS DISTINCT FROM source_valid_orders)
    AS source_count_mismatches,
  COUNTIF(ended_orders IS DISTINCT FROM
    valid_duration_orders + missing_start_orders + reversed_timestamp_orders)
    AS accounting_mismatches,
  COUNTIF(zero_duration_orders < 0 OR zero_duration_orders > valid_duration_orders)
    AS invalid_zero_counts,
  COUNTIF(valid_duration_share_pct IS DISTINCT FROM
    ROUND(SAFE_DIVIDE(valid_duration_orders, ended_orders) * 100, 2))
    AS coverage_mismatches,
  COUNTIF(average_days IS DISTINCT FROM
    ROUND(SAFE_DIVIDE(total_elapsed_days, valid_duration_orders), 2))
    AS average_mismatches,
  COUNTIF((total_elapsed_days IS NULL) != (source_elapsed_days IS NULL)
    OR ABS(total_elapsed_days - source_elapsed_days) > 0.000001)
    AS elapsed_total_mismatches,
  COUNTIF(
    (valid_duration_orders > 0 AND (
      approximate_median_days IS NULL OR approximate_p90_days IS NULL
      OR maximum_days IS NULL OR approximate_median_days < 0
      OR approximate_p90_days < approximate_median_days
      OR maximum_days < approximate_p90_days OR average_days < 0
      OR average_days > maximum_days
    ))
    OR (valid_duration_orders = 0 AND (
      average_days IS NOT NULL OR approximate_median_days IS NOT NULL
      OR approximate_p90_days IS NOT NULL OR maximum_days IS NOT NULL
    ))
  ) AS invalid_duration_summary_rows
FROM compared
GROUP BY duration_type
ORDER BY duration_type;
