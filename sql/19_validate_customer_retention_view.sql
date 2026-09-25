-- Validate the deployed customer_retention_cohorts view.
-- Expected: every Boolean check is TRUE and every mismatch count is zero.

WITH view_checks AS (
  SELECT
    COUNT(*) AS cohort_month_rows,
    COUNT(DISTINCT cohort_month) AS cohort_months,
    COUNTIF(months_since_first_purchase = 0) AS month_zero_rows,
    SUM(IF(months_since_first_purchase = 0, cohort_customers, 0))
      AS cohort_size_total,
    COUNT(*) - COUNT(DISTINCT CONCAT(
      CAST(cohort_month AS STRING),
      ':',
      CAST(months_since_first_purchase AS STRING)
    )) AS duplicate_cohort_age_rows,
    COUNTIF(months_since_first_purchase = 0 AND active_customers != cohort_customers)
      AS month_zero_customer_mismatches,
    COUNTIF(months_since_first_purchase = 0 AND retention_pct != 100)
      AS month_zero_retention_mismatches,
    COUNTIF(active_customers > cohort_customers OR active_customers < 0)
      AS invalid_active_customer_rows,
    COUNTIF(months_since_first_purchase NOT BETWEEN 0 AND 12)
      AS invalid_cohort_age_rows,
    COUNTIF(activity_month >= DATE_TRUNC(CURRENT_DATE(), MONTH))
      AS incomplete_or_future_month_rows,
    COUNTIF(retention_pct != ROUND(
      SAFE_DIVIDE(active_customers, cohort_customers) * 100,
      2
    )) AS retention_calculation_mismatches
  FROM `bigquery-analyst-practice.thelook_practice.customer_retention_cohorts`
),

source_buyers AS (
  SELECT COUNT(DISTINCT user_id) AS unique_buyers
  FROM `bigquery-public-data.thelook_ecommerce.order_items`
  WHERE status = 'Complete'
    AND delivered_at IS NOT NULL
    AND DATE(delivered_at) < DATE_TRUNC(CURRENT_DATE(), MONTH)
),

expected_rows AS (
  SELECT SUM(
    LEAST(
      12,
      DATE_DIFF(
        DATE_SUB(DATE_TRUNC(CURRENT_DATE(), MONTH), INTERVAL 1 MONTH),
        cohort_month,
        MONTH
      )
    ) + 1
  ) AS cohort_month_rows
  FROM `bigquery-analyst-practice.thelook_practice.customer_retention_cohorts`
  WHERE months_since_first_purchase = 0
)

SELECT
  v.cohort_month_rows,
  v.cohort_months,
  v.cohort_size_total,
  b.unique_buyers AS source_unique_buyers,
  v.cohort_month_rows = e.cohort_month_rows AS expected_rows_match,
  v.month_zero_rows = v.cohort_months AS one_month_zero_row_per_cohort,
  v.cohort_size_total = b.unique_buyers AS cohort_sizes_match_buyers,
  v.duplicate_cohort_age_rows,
  v.month_zero_customer_mismatches,
  v.month_zero_retention_mismatches,
  v.invalid_active_customer_rows,
  v.invalid_cohort_age_rows,
  v.incomplete_or_future_month_rows,
  v.retention_calculation_mismatches
FROM view_checks AS v
CROSS JOIN source_buyers AS b
CROSS JOIN expected_rows AS e;
