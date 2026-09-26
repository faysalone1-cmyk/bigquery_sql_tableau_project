-- Phase 5: monthly order-duration preview. Read-only.
-- Grain: one row per duration type and observed completed end-event month.
-- Shipping-to-delivery uses delivery month; delivery-to-return uses return month.
-- Missing end dates cannot be assigned a month and remain in the foundation audit.
-- Months without end events have no row; never interpret absent timing as zero.
-- Zero-duration events are retained and disclosed, not silently removed.
-- Durations are calendar days, not business days or service-level compliance.

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
ORDER BY duration_type, event_month;
