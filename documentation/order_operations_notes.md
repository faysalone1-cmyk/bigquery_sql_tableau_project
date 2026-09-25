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
