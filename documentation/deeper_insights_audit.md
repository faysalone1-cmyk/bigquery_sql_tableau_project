# Deeper Insights Source-Data Audit

This document records the results, interpretation, limitations, and modelling
decisions from `sql/09_deeper_insights_data_audit.sql`.

The audit is performed before creating the V2 analytical views so that every
published metric is supported by the source data and its limitations are
explicitly documented.

## Query 1 — Source Schema

### Findings

- `order_items` contains item, order, user, product, inventory, status,
  lifecycle timestamp, and sale-price fields.
- `orders` contains order, user, status, gender, lifecycle timestamp, and
  expected item-count fields.
- `products` contains product cost, category, name, brand, retail price,
  department, SKU, and distribution-centre fields.
- `users` contains customer demographics, location, acquisition source,
  registration timestamp, and geographic fields.
- All inspected columns are defined as nullable in the BigQuery schema.

### Interpretation and Decisions

- The schema supports the planned revenue, customer-retention, category,
  profitability, and order-operations analyses.
- Geography, traffic source, brand, department, and distribution centre are
  possible future dimensions but are not automatically included in V2.
- Schema nullability does not prove that null values exist. Actual null counts
  must be measured before each field is used.

## Query 2 — Order Status Distribution

| Status | Orders | Order share |
|---|---:|---:|
| Shipped | 37,502 | 30.02% |
| Complete | 30,829 | 24.67% |
| Processing | 25,009 | 20.02% |
| Cancelled | 18,789 | 15.04% |
| Returned | 12,813 | 10.26% |

### Interpretation and Decisions

- The valid order statuses are `Shipped`, `Complete`, `Processing`,
  `Cancelled`, and `Returned`.
- The status represents the currently recorded state, not a full event-history
  table showing every status transition.
- Recognized revenue will continue to use only `Complete` records with a
  non-null delivery timestamp.
- Operational rates must state their denominator explicitly. For example, a
  cancellation rate based on all created orders answers a different question
  from one based only on orders with a final outcome.
- Cancellation and return volumes are material enough to support a dedicated
  operational analysis.

## Query 3 — Order-Item Status Distribution

| Status | Order items | Distinct orders | Item share |
|---|---:|---:|---:|
| Shipped | 54,187 | 37,502 | 29.94% |
| Complete | 44,856 | 30,829 | 24.78% |
| Processing | 36,133 | 25,009 | 19.96% |
| Cancelled | 27,343 | 18,789 | 15.11% |
| Returned | 18,468 | 12,813 | 10.20% |

### Interpretation and Decisions

- The distinct-order count for every item status matches the corresponding
  order count from Query 2.
- Order-share and item-share percentages are very similar, suggesting that
  larger orders are not heavily concentrated in one status.
- `orders` is the likely source for order-level operational rates.
- `order_items` remains the source for revenue, product, item, and estimated
  profitability metrics.
- The relationship and status agreement will be formally tested in Query 7
  before this modelling decision is finalized.

## Query 4 — Lifecycle Timestamp Quality

| Status | Items | Missing created | Missing shipped | Missing delivered | Missing returned | Shipped before created | Delivered before shipped | Returned before delivered |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Shipped | 54,187 | 0 | 0 | 54,187 | 54,187 | 16,246 | 0 | 0 |
| Complete | 44,856 | 0 | 0 | 0 | 44,856 | 13,558 | 0 | 0 |
| Processing | 36,133 | 0 | 36,133 | 36,133 | 36,133 | 0 | 0 | 0 |
| Cancelled | 27,343 | 0 | 27,343 | 27,343 | 27,343 | 0 | 0 | 0 |
| Returned | 18,468 | 0 | 0 | 0 | 0 | 5,546 | 0 | 0 |

### Interpretation

- Timestamp presence is consistent with the recorded status:
  - Processing and Cancelled items have no later lifecycle timestamps.
  - Shipped items have shipped timestamps but no delivery or return timestamp.
  - Complete items have shipped and delivered timestamps but no return
    timestamp.
  - Returned items contain all lifecycle timestamps.
- No item is delivered before it is shipped.
- No item is returned before it is delivered.
- A material number of Shipped, Complete, and Returned items have a shipping
  timestamp earlier than their creation timestamp.

### Limitation and Treatment

- Created-to-shipped duration cannot be calculated safely across all records.
- Any future processing-time metric must exclude rows where
  `shipped_at < created_at` and disclose the excluded-row count and percentage.
- Shipping-to-delivery and delivery-to-return durations remain candidates
  because Query 4 found no reversed timestamps for those event pairs.
- The timestamp issue must not be silently corrected or hidden.

## Query 5 — Lifecycle Date Coverage

| Event | First date | Latest date |
|---|---:|---:|
| Created | 2019-01-05 | 2026-09-24 |
| Shipped | 2019-01-12 | 2026-09-23 |
| Delivered | 2019-01-13 | 2026-09-28 |
| Returned | 2019-02-21 | 2026-09-30 |

Query execution context:

- Current date: `2026-09-21`
- Current month start: `2026-09-01`

### Interpretation

- The available order-item history begins in January 2019.
- Return activity begins in February 2019.
- Every event type contains activity in the current incomplete month.
- The source also contains event dates later than the query execution date.
  The latest observed future dates extend to 30 September 2026.
- The public dataset is dynamic and appears to include generated lifecycle
  dates beyond today. Latest-date fields must not automatically be treated as
  completed historical events.

### Limitation and Treatment

- All monthly reporting views will continue to exclude the current incomplete
  calendar month using an event-date filter earlier than
  `DATE_TRUNC(CURRENT_DATE(), MONTH)`.
- Operational views must apply the complete-month rule to the event date that
  defines each metric.
- Future-dated events must never be included in as-of-today KPIs.
- Query 5A was added to quantify both future-dated records and current-month
  records before final operational business rules are defined.

## Query 5A — Future-Date and Current-Month Counts

Total order-item rows: `180,987`

| Event | Future-dated items | Share of all items | Current-month items | Share of all items |
|---|---:|---:|---:|---:|
| Created | 1,242 | 0.69% | 12,356 | 6.83% |
| Shipped | 1,081 | 0.60% | 8,266 | 4.57% |
| Delivered | 1,735 | 0.96% | 4,769 | 2.64% |
| Returned | 697 | 0.39% | 1,463 | 0.81% |

### Interpretation and Decisions

- Future-dated rows represent less than 1% of all item rows for each event,
  but they are still material and cannot be included in as-of-today metrics.
- Current-month counts are larger because they include both events that have
  already occurred this month and future-dated events later in the month.
- Current-month event counts are not mutually exclusive: the same item can be
  counted under multiple lifecycle timestamps.
- The project will use completed calendar months for comparable monthly trends.
  This rule excludes both partial current-month activity and the identified
  future-dated events.
- If an as-of-today operational KPI is introduced later, it must also use an
  explicit `event_date <= CURRENT_DATE()` filter.

## Query 6 — Key Uniqueness and Table Grains

| Table | Rows | Unique identifiers | Difference |
|---|---:|---:|---:|
| Orders | 124,942 | 124,942 | 0 |
| Order items | 180,987 | 180,987 | 0 |
| Products | 29,120 | 29,120 | 0 |
| Users | 100,000 | 100,000 | 0 |

### Interpretation and Decisions

- No duplicate primary identifiers were found in the four core tables.
- The confirmed grains are:
  - `orders`: one row per `order_id`.
  - `order_items`: one row per item `id`.
  - `products`: one row per product `id`.
  - `users`: one row per user `id`.
- These tables can be joined through their documented identifiers without
  first deduplicating a source table.
- Join coverage and order/item attribute agreement still require Query 7;
  primary-key uniqueness alone does not prove referential integrity.

## Query 7 — Join Coverage and Order/Item Consistency

Total order-item rows tested: `180,987`

| Test | Exceptions |
|---|---:|
| Items without a matching order | 0 |
| Items without a matching product | 0 |
| Items without a matching user | 0 |
| Item/order user mismatches | 0 |
| Item/order status mismatches | 0 |

### Interpretation and Decisions

- All tested foreign-key relationships have complete coverage.
- The user and status recorded on each item agree with its parent order.
- Inner joins from `order_items` to `orders`, `products`, or `users` will not
  remove rows under the current source snapshot.
- Order-level status rates and counts will use `orders`, avoiding unnecessary
  item-level duplication.
- Revenue, product, category, item, and estimated-profit metrics will use
  `order_items` joined to `products` where product attributes or cost are
  required.
- Customer analyses can safely connect completed order-item revenue to the
  registered user table through `user_id`.
- Query 3's preliminary order/item consistency conclusion is now confirmed.

## Query 8 — Price and Cost Quality

Total order-item rows tested: `180,987`

| Test | Result |
|---|---:|
| Missing sale prices | 0 |
| Negative sale prices | 0 |
| Missing matched product costs | 0 |
| Negative product costs | 0 |
| Items sold below product cost | 0 |
| Minimum sale price | $0.02 |
| Maximum sale price | $999.00 |
| Average sale price | $59.53 |

### Interpretation and Decisions

- Sale price and product cost are complete for all item rows.
- No negative financial values were found.
- No item was sold below its matched product cost, so the current estimated
  gross-profit calculation does not generate a loss at item level.
- The fields are structurally suitable for revenue and estimated gross-profit
  analysis.
- The `$0.02` minimum is unusually low and must be quantified before the full
  price range is considered analytically representative.
- Query 8A was added to inspect price percentiles, extreme-value counts, and
  differences between item sale price and product retail price.

## Query 8A — Sale-Price Distribution and Outliers

Total order-item rows tested: `180,987`

| Measure | Result | Share of all items |
|---|---:|---:|
| Items below $1 | 11 | 0.006% |
| Items below $5 | 934 | 0.52% |
| Items above $500 | 440 | 0.24% |
| Sale/retail price differences | 0 | 0.00% |
| 1st-percentile sale price | $6.50 | — |
| Median sale price | $39.99 | — |
| 99th-percentile sale price | $308.00 | — |

### Interpretation and Decisions

- The `$0.02` minimum is an extreme edge value rather than a representative
  price: only 11 items are priced below $1.
- Fewer than 1% of items fall below $5, and fewer than 1% exceed $500.
- The central price distribution is plausible, with a median of `$39.99` and
  the middle 98% approximately bounded by `$6.50` and `$308.00`.
- Every item sale price matches the associated product retail price within the
  one-cent comparison tolerance.
- No price-based rows will be excluded from revenue or profitability analysis.
  The extreme values appear sparse and valid under the available source rules.
- Future price-band visuals should use carefully selected bins or a logarithmic
  scale if the full `$0.02` to `$999.00` range is displayed.

## Query 9 — Expected Versus Actual Item Counts

| Measure | Result |
|---|---:|
| Joined orders | 124,942 |
| Orders with matching item counts | 124,942 |
| Orders with mismatching item counts | 0 |
| Largest item-count difference | 0 |

### Interpretation and Decisions

- `orders.num_of_item` agrees exactly with the number of related
  `order_items` rows for every order.
- The order-level item-count field is reliable under the current source
  snapshot.
- Order-level operational views can use `num_of_item` without joining and
  recounting item rows when no item-level dimensions or financial measures are
  required.
- Item-level analysis will continue using `order_items`, preserving its natural
  grain and access to product and revenue fields.

## Query 10 — Complete-Month Calendar Continuity

### Findings

- The generated calendar begins in January 2019, the first completed delivery
  month.
- `is_missing_delivery_month` is `FALSE` for the first row after sorting the
  flag descending. Therefore, no missing completed delivery month exists in
  the returned period.
- Every calendar month in the completed delivery range contains completed
  orders, completed items, and recognized revenue.

### Interpretation and Decisions

- The completed monthly revenue series is continuous under the current source
  snapshot.
- `LAG(..., 1)` currently represents the immediately preceding calendar month,
  not merely the previous available row.
- A generated calendar remains preferable for production-style analytical
  views because future source snapshots could contain a missing month.
- Rolling and year-over-year calculations may proceed, provided the complete-
  month filter remains in place.

## Phase 1 Audit Conclusion

### Approved for V2

- Completed-month recognized revenue and order metrics
- Month-over-month and year-over-year comparisons
- Rolling monthly revenue and order calculations
- Customer purchase-history and cohort analysis
- Category, brand, department, and product performance
- Estimated gross profit and gross-margin analysis
- Order-status, cancellation, and return-rate analysis
- Shipping-to-delivery and delivery-to-return duration analysis

### Required Safeguards

- Exclude the current incomplete calendar month from comparable monthly trends.
- Exclude future-dated lifecycle events from as-of-today metrics.
- Do not calculate created-to-shipped processing time without excluding and
  disclosing records where `shipped_at < created_at`.
- State the denominator for every operational rate.
- Treat status as the currently recorded outcome, not a complete event history.
- Use order grain for order-level rates and item grain for financial and
  product-level metrics.
- Continue using `NUMERIC` aggregation and `SAFE_DIVIDE` for financial ratios.

### Audit Status

Phase 1 is complete. The source data is suitable for the planned deeper-insight
views when the documented safeguards are applied.
