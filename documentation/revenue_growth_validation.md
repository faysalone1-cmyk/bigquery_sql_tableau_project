# Revenue Growth Validation

This document records the validation of the permanent BigQuery view:

`bigquery-analyst-practice.thelook_practice.monthly_revenue_growth`

Validation was completed on 22 September 2026 using the source data available
at that time.

## Business Rules

- Include only order items with `status = 'Complete'`.
- Require a non-null `delivered_at` timestamp.
- Assign revenue to the delivery month.
- Exclude the current incomplete calendar month.
- Generate a continuous calendar before calculating window metrics.
- Return `NULL` until a complete 3- or 12-month rolling window exists.

## Pre-Deployment Validation

The analysis logic was tested in a BigQuery temporary table before the
permanent view was created.

- 92 monthly rows and 92 unique months.
- Continuous coverage from January 2019 through August 2026.
- One expected null previous-month row.
- 12 expected null previous-year rows.
- Two expected null rolling 3-month rows.
- 11 expected null rolling 12-month rows.
- Zero AOV, month-over-month, or year-over-year calculation mismatches.
- Zero rolling 3-month or rolling 12-month calculation mismatches.

The totals also reconciled with the existing `monthly_revenue` reporting view.

## Post-Deployment Validation

The deployed view returned:

- 28,571 completed orders.
- 41,518 completed items.
- $2,469,886.01 recognized revenue.

The following checks all returned `TRUE`:

- One row per month.
- Calendar continuity.
- Latest month is a completed month.
- Completed orders match the existing monthly revenue view.
- Completed items match the existing monthly revenue view.
- Recognized revenue matches the existing monthly revenue view.

## Interpretation Notes

- Positive growth values indicate an increase; negative values indicate a
  decrease.
- Month-over-month percentages compare with the immediately preceding calendar
  month.
- Year-over-year percentages compare with the same month 12 months earlier.
- Percentage growth can appear unusually large when the comparison-period
  revenue is small, so dashboards should show percentage and absolute change
  together.
- Query results should explicitly sort by `revenue_month`; a BigQuery view does
  not guarantee display order.

## Related SQL Files

- `sql/10_monthly_revenue_growth.sql`
- `sql/11_validate_monthly_revenue_growth.sql`
- `sql/12_create_monthly_revenue_growth_view.sql`
- `sql/13_validate_monthly_revenue_growth_view.sql`
