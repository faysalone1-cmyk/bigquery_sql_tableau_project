-- Customer retention by first completed-purchase delivery month.
-- Grain: one row per cohort month and elapsed calendar month (0 through 12).
--
-- A customer is active in a month if at least one item with status = 'Complete'
-- was delivered in that month. DISTINCT removes multiple items or orders from
-- the same customer's month. The first active month defines the cohort.
--
-- A calendar spine adds zero-activity months, but stops at the latest completed
-- month. Thus recent cohorts are not assigned future or incomplete periods.
-- Month 0 retention is 100%; later months measure return activity, not the
-- percentage of customers who have ever made a second purchase.

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
)

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
ORDER BY s.cohort_month, s.months_since_first_purchase;
