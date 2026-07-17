# E-Commerce Order Analytics System

This project generates dirty e-commerce data, cleans it into analysis-ready CSVs, and runs SQLite analytics through SQL files plus a small reporting CLI.

The implementation uses only course-level concepts: variables, lists, dictionaries, loops, if-else, pandas CSV loading, basic cleaning, filtering, grouping, aggregation, derived columns, SQLite tables, constraints, joins, CTEs, CASE statements, and window functions. `Faker` is used only for fake names/emails.

```
scripts/generate_data.py -> data/raw
scripts/clean_data.py    -> data/cleaned
scripts/report_cli.py    -> in-memory SQLite using sql/schema.sql
sql/*.sql                -> analytics queries
```

## Quickstart

```bash
pip install pandas faker
python scripts/generate_data.py
python scripts/clean_data.py
python scripts/report_cli.py --report monthly --start 2026-01-01 --end 2026-06-30
```

Run the CLI directly:

```bash
python scripts/report_cli.py --report monthly --start 2026-01-01 --end 2026-06-30
python scripts/report_cli.py
```

The scripts use `pandas`, SQLite, and `Faker`.

## Business Rules

| # | Decision |
|---|---|
| BR-1 | Cancelled orders are excluded from revenue in `v_revenue`. |
| BR-2 | Negative quantity is a real return and is preserved. |
| BR-3 | Line-level return truth is the sign of `quantity`; `RETURNED` orders contain at least one negative line. |
| BR-4 | Null `customer_id` is kept as a guest order with `is_guest=1`. |
| BR-5 | `quantity = 0` is quarantined. |
| BR-6 | `discount_percent > 100` is quarantined. |
| BR-7 | Future `order_date` is quarantined and its child items are quarantined as cascade orphans. |
| BR-8 | Money uses SQLite `REAL`; presentation is rounded to two decimals. |
| BR-9 | Dates are stored as ISO-8601 text. |
| BR-10 | Rolling windows anchor to `MAX(order_date)` in the DB, not wall-clock time. |
| BR-11 | Return rate is unit based: returned absolute units divided by total absolute units. |

## Data Dictionary

`customers`: `customer_id`, `customer_name`, `email`, `registration_date`, `customer_type`, `region_code`, `email_valid`.

`products`: `product_id`, `product_name`, `category`, `subcategory`, `cost_price`.

`orders`: `order_id`, nullable `customer_id`, `order_date`, `status`, `region_code`, `is_guest`.

`order_items`: `item_id`, `order_id`, `product_id`, `quantity`, `unit_price`, `discount_percent`.

Derived views:

`v_line` enriches each order line with product/order columns plus `net_revenue`, `gross_revenue`, `return_value`, `is_return`, `order_day`, and `order_month`.

`v_revenue` filters out cancelled orders and is the source for revenue analytics.

`v_month_spine` creates dense month rows so missing months show as zero instead of disappearing.

## Queries

`sql/aggregations.sql`: Q1-Q6.

`sql/window_functions.sql`: Q7-Q14 and Q16.

`sql/cohort_analysis.sql`: Q15.

SQLite syntax is used for date grouping and basic date differences.

## Data Quality

The generator deliberately injects null customer ids, negative quantities, dirty names, invalid emails, orphan items, invalid discounts, zero quantities, future dates, duplicates, and junk dates. The cleaner keeps only analysis-ready rows in `data/cleaned`.

## Spec Conflicts Resolved

The reporting CLI avoids `tabulate` and hand-rolls table output.

The interface supports both command-line arguments and interactive prompts.

Cohort analysis uses registration month as the primary cohort, matching the assignment requirement.

The project generates 5,000 orders instead of exactly 500 because retention, YoY, customer gaps, Pareto, and product-pair queries need enough history and repeated behavior to be meaningful.

## Known Limitations

Email validation uses a practical regex rather than full RFC 5322 validation.

Money is stored as floating point for assignment simplicity.

The pipeline rebuilds from scratch and does not implement incremental loading.
