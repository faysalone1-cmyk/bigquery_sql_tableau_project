# Customer Retention Analysis Notes

## Scope and Definitions

- Cohort month: the first completed calendar month in which a customer has an
  order item with `status = 'Complete'` and a non-null delivery timestamp.
- Monthly activity: at least one such completed item delivered for that
  customer in the month. Multiple items and orders within a month count once.
- Cohort size: distinct customers whose first qualifying month is the cohort
  month.
- Month N retention: customers active in calendar month N after their cohort
  month, divided by the original cohort size. Month 0 is 100%.
- The current incomplete month and future months are excluded. The matrix
  covers elapsed months 0 through 12 only.
- Month N retention does not require activity in every preceding month. A
  customer may be inactive in month 1 and return in month 2.
- This monthly activity measure differs from the existing `Repeat customer`
  segment, which means more than one completed order in any time period.

## Foundation Check — 25 September 2026

The foundation query returned:

| Measure | Result |
|---|---:|
| Customer rows | 25,490 |
| Unique buyers | 25,490 |
| Missing user IDs | 0 |
| Customer-month rows | 28,596 |
| Customers active in multiple months | 2,826 |
| First cohort month | February 2019 |
| Latest cohort month | August 2026 |

The first cohort month differed from the January 2019 start recorded during
the revenue-growth validation on 22 September 2026. A focused source and view
check on 25 September showed no completed deliveries in January 2019. February
contained four completed items, two completed orders, two unique buyers, and
`$229.55` recognized revenue. Both reporting views matched the current source.

The public dataset changes over time. Historical validation figures document
the source snapshot at the time of the check; they are not fixed expected
values for later runs. Cohort and revenue views are live and therefore reflect
the current source when queried.

## Pre-Deployment Validation — 25 September 2026

The first page of `sql/16_customer_retention_cohorts.sql` returned 1,105 total
cohort-month rows. The February 2019 cohort contained two customers, with
month-0 retention of 100% and no activity in the following 12 months. The
March 2019 cohort contained eight customers. A customer from the April 2019
cohort returned in its fifth elapsed month, producing 7.14% retention for that
month (one of 14 cohort customers). These observations are illustrative; the
full result still requires validation.

`sql/17_validate_customer_retention_cohorts.sql` returned:

- 1,105 cohort-month rows across 91 cohorts.
- 25,490 unique buyers; summed cohort sizes also equalled 25,490.
- 91 month-0 rows, one per cohort.
- 538 later cohort-month rows with at least one returning customer.
- All three Boolean checks returned `TRUE`.
- Every mismatch and invalid-row count returned zero.

The checks covered:

- Every cohort has exactly one month-0 row with retention of 100%.
- Cohort size is constant across a cohort's elapsed months.
- Active customers never exceed cohort size.
- No activity month is the current incomplete month or a future month.
- The total of cohort sizes equals the distinct completed-purchase buyers in
  the current source snapshot.
- Recent cohorts have only the elapsed months that have actually completed.

The validated calculation was deployed through
`sql/18_create_customer_retention_view.sql` as
`bigquery-analyst-practice.thelook_practice.customer_retention_cohorts`.

## Post-Deployment Validation — 25 September 2026

`sql/19_validate_customer_retention_view.sql` returned:

- 1,105 cohort-month rows across 91 cohorts.
- 25,490 summed cohort customers, matching 25,490 unique buyers from the
  current source.
- All three Boolean checks returned `TRUE`.
- Every duplicate, mismatch, invalid-row, and incomplete-month count returned
  zero.

The BigQuery view is ready for a future Tableau customer-retention page. It is
not yet part of the existing dashboard image or workbook.

## Interpretation Cautions

- Early cohorts are very small. For example, February 2019 has only two
  customers, so its percentage alone is not a stable summary of overall
  retention. Display cohort size beside retention percentages.
- Month N retention measures activity in that exact month. It may increase
  again after a customer returns from an inactive month.
- The source records the current item status, not a full history of status
  changes. A previously completed item that later changes status may alter
  historical cohort assignments or retention when the live view is queried.
- Cohorts with fewer than 12 completed follow-up months must not be treated as
  having zero retention in unobserved future periods.
