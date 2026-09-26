# Order Operations Notes

## Foundation Check — 2026-09-25

The read-only order-grain check in `sql/25_order_operations_foundation.sql`
was run in BigQuery. The public source changes over time, so these are
snapshot results rather than fixed historical totals.

| Check | Result |
|---|---:|
| All order rows | 124,362 |
| Missing creation timestamp | 0 |
| Created in current or future month | 9,165 |
| Future-created orders | 0 |
| Eligible orders created before current month | 115,197 |
| Unique eligible order IDs | 115,197 |
| First eligible creation date | 2019-01-19 |
| Last eligible creation date | 2026-08-31 |
| Processing | 22,939 |
| Shipped | 34,503 |
| Complete | 28,910 |
| Cancelled | 17,322 |
| Returned | 11,523 |

Missing and unexpected statuses, Complete orders without delivery dates,
Returned orders without return dates, reversed order-level lifecycle
timestamps, and future-dated shipment, delivery, and return events were all
zero among eligible orders. Both one-row-per-order and known-status coverage
checks returned `true`.

Using all 115,197 eligible orders as the denominator, the current status
shares were 15.04% Cancelled, 10.00% Returned, and 25.10% Complete. These
are snapshot shares, not the probability that an order will eventually end
in each status: Processing and Shipped orders may change status later.

The earlier item-grain audit found some item shipment timestamps earlier than
item creation timestamps. This order-grain check found zero such cases among
eligible orders. The difference in grain and source snapshot matters; no
created-to-shipped duration metric is approved solely from this check.

## Next Preview

`sql/26_monthly_order_status_preview.sql` groups orders by creation month and
shows their current status mix. Recent months have had less time to reach a
final status, so status shares across creation months should not be read as
directly comparable final-outcome rates.

## Monthly Preview — 2026-09-26

The preview spans January 2019 through August 2026 (92 calendar months).
August shows 5,651 created orders: 1,087 Processing, 1,679 Shipped,
1,445 Complete, 846 Cancelled, and 594 Returned. These status counts sum
to 5,651. The displayed shares are 14.97% Cancelled, 10.51% Returned, and
25.57% Complete.

Even old creation cohorts contain Processing and Shipped records. Therefore
`currently_open_orders` means orders recorded in those two statuses; it is
not evidence of an actual live operational backlog or overdue orders. Do not
infer delivery delays from status age alone.

Run `sql/27_validate_monthly_order_status.sql` to check all monthly rows,
calendar continuity, source totals, status counts, and percentage formulas.

## Monthly Validation — 2026-09-26

The validation returned 92 rows and 92 unique months, from January 2019
through August 2026. The monthly order total and source total were both
115,508. There were zero incomplete/future months, status-count mismatches,
open-count mismatches, or cancelled/returned/complete percentage mismatches.
All three final Boolean checks returned `true`.

The order total differs from the September 25 foundation result (115,197).
The public source is mutable; the same-run reconciliation passed, so the old
snapshot is retained as historical evidence rather than overwritten.

`monthly_status_validation` is a temporary script table, not the permanent
reporting layer.

## Deployed View Validation — 2026-09-26

`bigquery-analyst-practice.thelook_practice.monthly_order_status` was deployed
using script 28. Script 29 returned 92 unique months, January 2019 through
August 2026, and 115,508 orders matching the source. All six exception counts
were zero and all three final Boolean checks were `true`.

The monthly status reporting component is deployed and validated. Delivery
and return-duration analysis remains separate work; these status checks do
not validate operational durations or service-level performance.
