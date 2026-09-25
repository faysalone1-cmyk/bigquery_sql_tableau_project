# Product and Category Performance Notes

## Foundation Check — 2026-09-25

The read-only check in `sql/20_product_category_foundation.sql` was run in
BigQuery. The public source may change, so these numbers describe this run,
not a fixed historical snapshot.

| Check | Result |
|---|---:|
| Completed item rows | 41,499 |
| Unique completed item IDs | 41,499 |
| Unmatched products | 0 |
| Missing category labels | 0 |
| Missing product names | 0 |
| Missing product costs | 0 |
| Negative product costs | 0 |
| Missing sale prices | 0 |
| Negative sale prices | 0 |
| Categories | 26 |
| Products sold | 22,044 |
| Recognized revenue | $2,462,889.58 |
| Estimated gross profit | $1,277,992.27 |

The monthly revenue and category-performance views both report 41,499 items
and $2,462,889.58 recognized revenue. The category view also reports
$1,277,992.27 estimated gross profit. The one-row-per-item, monthly-view,
and category-view checks all returned `true`.

## Modelling Decisions

- Product performance uses one row per product ID, including its name and
  category for display. A product name alone is not assumed to be unique.
- Revenue uses completed items with a delivery date in a finished calendar
  month, matching the existing reporting views.
- Product cost is the value currently recorded in the product table. Therefore
  gross profit is an estimate, not a historical cost-of-goods-sold ledger or
  net profit. Cost changes in the source could restate past estimates.
- Completed order counts are distinct within each product or category. They
  must not be added across products or categories because an order can contain
  multiple products.
- `sql/21_product_performance.sql` is a top-50 preview. Its output totals
  must not be compared with all-product or all-category totals.

## Product Preview — 2026-09-25

The top-50 product preview ran successfully and returned 50 rows ordered by
recognized revenue. The leading product was ID `24447` ("Darla") with four
completed items and $3,996 recognized revenue. This is an exploratory result,
not an all-product validation. Run `sql/22_validate_product_performance.sql`
before publishing a product-performance view.

## All-Product Validation — 2026-09-25

The predeployment validation passed: 22,044 product rows, 22,044 unique
products, 41,499 completed items, $2,462,889.58 recognized revenue, and
$1,277,992.27 estimated gross profit. All three checks returned `true`,
including zero mismatches across 26 categories. The deployed view must be
checked again with `sql/24_validate_product_performance_view.sql` because the
public source is mutable.

## Deployed View Validation — 2026-09-25

The `product_performance` view was created in
`bigquery-analyst-practice.thelook_practice`. Its schema contains product ID,
name, category, revenue ranks, completed order and item counts, recognized
revenue, estimated product cost, estimated gross profit, gross margin, and
revenue-share percentages.

The postdeployment check returned 22,044 product rows and 22,044 unique IDs,
41,499 completed items, $2,462,889.58 recognized revenue, and $1,277,992.27
estimated gross profit. It found zero missing product attributes, zero invalid
ranks, and zero mismatches across 26 categories. All three final Boolean
checks returned `true`. This validates the deployed view against the source
and existing category view for this source snapshot.
