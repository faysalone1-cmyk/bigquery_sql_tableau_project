-- Validate the cohort logic before creating a permanent reporting view.
-- Expected: all mismatch counts are zero and all Boolean checks are TRUE.

WITH customer_month_activity AS (
  SELECT DISTINCT
    user_id,
    DATE_TRUNC(DATE(delivered_at), MONTH) AS activity_month
  FROM `bigquery-public-data.thelook_ecommerce.order_items`
  WHERE status = 'Complete'
    AND delivered_at IS NOT NULL
    AND DATE(delivered_at) < DATE_TRUNC(CURRENT_DATE(), MONTH)
    AND user_id IS NOT NULL
),

customer_cohorts AS (
  SELECT
    user_id,
    MIN(activity_month) AS cohort_month
  FROM customer_month_activity
  GROUP BY user_id
),

cohort_sizes AS (
  SELECT
    cohort_month,
    COUNT(*) AS cohort_customers
  FROM customer_cohorts
  GROUP BY cohort_month
),

cohort_activity AS (
  SELECT
    c.cohort_month,
    DATE_DIFF(a.activity_month, c.cohort_month, MONTH)
      AS months_since_first_purchase,
    COUNT(*) AS active_customers
  FROM customer_month_activity AS a
  INNER JOIN customer_cohorts AS c
    ON a.user_id = c.user_id
  WHERE DATE_DIFF(a.activity_month, c.cohort_month, MONTH) BETWEEN 0 AND 12
  GROUP BY c.cohort_month, months_since_first_purchase
),

cohort_month_spine AS (
  SELECT
    s.cohort_month,
    s.cohort_customers,
    months_since_first_purchase
  FROM cohort_sizes AS s
  CROSS JOIN UNNEST(
    GENERATE_ARRAY(
      0,
      LEAST(
        12,
        DATE_DIFF(
          DATE_SUB(DATE_TRUNC(CURRENT_DATE(), MONTH), INTERVAL 1 MONTH),
          s.cohort_month,
          MONTH
        )
      )
    )
  ) AS months_since_first_purchase
),

retention AS (
  SELECT
    s.cohort_month,
    s.months_since_first_purchase,
    DATE_ADD(
      s.cohort_month,
      INTERVAL s.months_since_first_purchase MONTH
    ) AS activity_month,
    s.cohort_customers,
    COALESCE(a.active_customers, 0) AS active_customers,
    ROUND(
      SAFE_DIVIDE(
        COALESCE(a.active_customers, 0),
        s.cohort_customers
      ) * 100,
      2
    ) AS retention_pct
  FROM cohort_month_spine AS s
  LEFT JOIN cohort_activity AS a
    ON s.cohort_month = a.cohort_month
    AND s.months_since_first_purchase = a.months_since_first_purchase
)

SELECT
  COUNT(*) AS cohort_month_rows,
  COUNT(DISTINCT cohort_month) AS cohort_months,
  (SELECT COUNT(*) FROM customer_cohorts) AS source_unique_buyers,
  SUM(IF(months_since_first_purchase = 0, cohort_customers, 0))
    AS cohort_size_total,
  COUNTIF(months_since_first_purchase = 0) AS month_zero_rows,
  COUNTIF(months_since_first_purchase > 0 AND active_customers > 0)
    AS nonzero_return_rows,

  COUNT(*) = (
    SELECT SUM(
      LEAST(
        12,
        DATE_DIFF(
          DATE_SUB(DATE_TRUNC(CURRENT_DATE(), MONTH), INTERVAL 1 MONTH),
          cohort_month,
          MONTH
        )
      ) + 1
    )
    FROM cohort_sizes
  ) AS expected_spine_rows_match,
  COUNTIF(months_since_first_purchase = 0)
    = COUNT(DISTINCT cohort_month) AS one_month_zero_row_per_cohort,
  SUM(IF(months_since_first_purchase = 0, cohort_customers, 0))
    = (SELECT COUNT(*) FROM customer_cohorts) AS cohort_sizes_match_buyers,

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
  COUNTIF(activity_month != DATE_ADD(
    cohort_month,
    INTERVAL months_since_first_purchase MONTH
  )) AS activity_month_mismatches,
  COUNTIF(activity_month >= DATE_TRUNC(CURRENT_DATE(), MONTH))
    AS incomplete_or_future_month_rows,
  COUNTIF(retention_pct != ROUND(
    SAFE_DIVIDE(active_customers, cohort_customers) * 100,
    2
  )) AS retention_calculation_mismatches,
  (
    SELECT COUNT(*)
    FROM (
      SELECT cohort_month
      FROM retention
      GROUP BY cohort_month
      HAVING MIN(cohort_customers) != MAX(cohort_customers)
    )
  ) AS cohorts_with_changing_size
FROM retention;
