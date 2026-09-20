# E-commerce Analytics Dashboard

An end-to-end analytics portfolio project using BigQuery, GoogleSQL, Tableau, and GitHub. The project transforms raw e-commerce data into reporting views and presents the results through an interactive performance dashboard.

## Dashboard Preview

![E-commerce Performance Dashboard](documentation/images/ecommerce_performance_dashboard.png)

## Business Questions

This project explores:

- How has recognized revenue changed over time?
- Which product categories generate the most revenue?
- How many orders have been completed?
- What is the overall average order value?
- What is the estimated gross margin?
- How is the customer base divided by purchasing behaviour?

## Key Performance Indicators

- Recognized Revenue
- Completed Orders
- Average Order Value
- Gross Margin

The dashboard only includes completed delivery months, preventing incomplete current-month data from distorting the results.

## Dashboard Views

- Monthly recognized revenue trend
- Top 10 categories by recognized revenue
- Customer segmentation by purchase behaviour
- Executive KPI cards

## Tools and Technologies

- **BigQuery** — data exploration and reporting views
- **GoogleSQL** — transformation, aggregation, and validation
- **Tableau** — dashboard development and visualization
- **Git and GitHub** — version control and project documentation
- **VS Code** — SQL and repository management

## Repository Structure

```text
├── documentation/
│   ├── images/
│   │   └── ecommerce_performance_dashboard.png
│   └── metrics.md
├── sql/
│   ├── 01_basic_queries.sql
│   ├── 02_orders_overview.sql
│   ├── 03_order_items_profile.sql
│   ├── 04_monthly_revenue.sql
│   ├── 05_category_performance.sql
│   ├── 06_customer_behavior.sql
│   ├── 07_create_reporting_views.sql
│   └── 08_validate_reporting_views.sql
├── Tableau/
│   └── ecommerce_analytics_dashboard.twb
├── .gitignore
└── README.md
```

## Data Workflow

1. Explore the source tables in BigQuery.
2. Profile orders, order items, customers, and products.
3. Define the project metrics and business rules.
4. Create aggregated reporting views.
5. Validate totals across the reporting views.
6. Connect Tableau to the BigQuery views.
7. Build and format the final dashboard.

## Data Source

The project uses the public `bigquery-public-data.thelook_ecommerce` dataset.

Reporting views were created in:

```text
bigquery-analyst-practice.thelook_practice
```

## Metric Definitions

Detailed metric definitions and business rules are available in [`documentation/metrics.md`](documentation/metrics.md).

## Tableau Workbook

The Tableau workbook is available at:

[`Tableau/ecommerce_analytics_dashboard.twb`](Tableau/ecommerce_analytics_dashboard.twb)

Because the workbook uses live BigQuery connections, users may need to authenticate with Google Cloud and update the connection details when opening it locally.

## Author

**Faisal Mughal**