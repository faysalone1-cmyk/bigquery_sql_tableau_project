-- Phase 3: customer-retention foundation check.
--
-- A customer is active in a month when at least one of their order items has
-- status = 'Complete' and was delivered in that month.
-- The first such month is the customer's completed-purchase cohort month.
-- Only completed calendar months are included.
--
-- This query checks the customer-month grain before a retention matrix is built.
-- A customer active in multiple months is not necessarily a repeat customer
-- under the existing order-count definition: two orders could occur in one month.

WITH customer_month_activity AS (
  SELECT DISTINCT
    user_id,
    DATE_TRUNC(DATE(delivered_at), MONTH) AS activity_month
  FROM `bigquery-public-data.thelook_ecommerce.order_items`
  WHERE status = 'Complete'
    AND delivered_at IS NOT NULL
    AND DATE(delivered_at) < DATE_TRUNC(CURRENT_DATE(), MONTH)
),

customer_cohorts AS (
  SELECT
    user_id,
    MIN(activity_month) AS cohort_month,
    COUNT(*) AS active_months
  FROM customer_month_activity
  GROUP BY user_id
)

SELECT
  COUNT(*) AS customer_rows,
  COUNT(DISTINCT user_id) AS unique_buyers,
  COUNTIF(user_id IS NULL) AS missing_user_ids,
  SUM(active_months) AS customer_month_rows,
  COUNTIF(active_months > 1) AS customers_active_in_multiple_months,
  MIN(cohort_month) AS first_cohort_month,
  MAX(cohort_month) AS latest_cohort_month
FROM customer_cohorts;
