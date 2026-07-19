# Secure Retail Data Lakehouse

Batch pipeline that strips PII and cardholder data out of retail operational data before it reaches
analysts. Records land with full names, street addresses, dates of birth, card numbers and CVVs. What
comes out the far end is purchase trends keyed on an irreversible token.

```
sql/create_tables.sql     Delta DDL for retail_db
scripts/                  Databricks notebooks, exported as source
data/                     output snapshot pulled down for review; nothing reads it
```

## Running this

Built on Databricks and it only runs there. The files in `scripts/` are notebooks exported as
source, carrying the `# Databricks notebook source` header and `# COMMAND ----------` cell markers.
Import them through Workspace > Import > File and they reopen as notebooks. They use the injected
`spark` and `dbutils` handles (there is no `SparkSession.builder` call anywhere in the codebase),
read and write to a Unity Catalog Volume at `/Volumes/workspace/default/retail_data/`, and
`create_tables.sql` leads with a `%sql` magic. None of that survives off-cluster.

You need Unity Catalog enabled, a running cluster, `faker` on it (`%pip install faker`), and rights to
create a Volume and database under `workspace.default`. The Volume must exist before anything else
runs; that code sits commented out at the top of [data_generation.py](scripts/data_generation.py#L11-L16).
Uncomment it, run it once, comment it back.

## Order

| | | |
|---|---|---|
| 1 | [sql/create_tables.sql](sql/create_tables.sql) | creates `retail_db` and four Delta tables |
| 2 | [scripts/data_generation.py](scripts/data_generation.py) | synthetic source data into `raw/` |
| 3 | [scripts/data_loading.py](scripts/data_loading.py) | `raw/` into the Delta tables |
| 4 | [scripts/data_quality.py](scripts/data_quality.py) | profiles `raw/`, writes nothing |
| 5 | [scripts/data_cleaning.py](scripts/data_cleaning.py) | `raw/` into `clean/` |
| 6 | masking notebook | `clean/` into `secure/` and `silver/`; not in this repo |
| 7 | gold notebook | `silver/` into `gold/`; not in this repo |

Step 4 is a report and can be skipped or re-run at will. Steps 6 and 7 are covered below.

## The files

**create_tables.sql** builds `retail_db` with customers, products, orders and payments, PK/FK
constraints, Delta throughout. This is the landing schema, so it still declares `dob`, `address`,
`card_number` and `cvv`. The tables are therefore as sensitive as `raw/` and need the same access
restrictions.

**data_generation.py** produces a thousand customers, three hundred products across seven categories,
seven thousand orders spread over two years, and one payment per order, written as headered CSV per
dataset. It generates the worst case deliberately: exact dates of birth, street addresses, card
numbers, CVVs.

**data_loading.py** reads the four raw CSV directories with schema inference, appends them to the
Delta tables, and prints a row count per table. It appends, so a second run doubles every table.
Truncate first or switch the mode to overwrite.

**data_quality.py** is a read-only profile of `raw/`: nulls per column, exact-duplicate and
duplicate-key counts, business rules (negative prices, non-positive quantities, malformed emails,
future signup dates), referential integrity by left-anti join in three directions, orders and revenue
by status, and a summary DataFrame. It establishes what condition the data arrives in and changes
nothing.

**data_cleaning.py** casts the four date columns, dedupes on primary key, fills missing phone and
address with "Not Provided", drops orders missing any key, trims and initcaps names, cities, states
and categories, normalises phone to `(XXX) XXX-XXXX`, drops rows whose email fails a regex, prints
surviving counts, and writes CSV to `clean/`. Note it reads `raw/` rather than the Delta tables. The
tables from step 3 are a parallel landing target, not an input to cleansing.

## Steps 6 and 7 are missing

`data/secure/`, `data/silver/` and `data/gold/` are fully populated, but the notebooks that produced
them were never exported from the workspace. Steps 1 through 5 re-run end to end; the masking layer
that gives this project its name does not. Export those two notebooks into `scripts/` and commit them.

Everything below is reconstructed from the output files. It is an accurate account of what ran and a
usable spec for rebuilding it. It is not documentation of code you can execute today.

### Masking

Three things happen. Columns are dropped outright: `cvv`, which PCI-DSS forbids retaining at all;
`dob`, replaced by a band; and `customer_id`, replaced by a token.

Direct identifiers are masked. Verified against `data/secure/customers/`:

| field | raw | stored |
|---|---|---|
| `customer_name` | `Patrick Duran` | `P***` |
| `email` | `ortegamatthew@example.org` | `o***@example.org` |
| `phone` | `(930) 417-7541` | `(XXX) XXX-7541` |
| `address` | `099 Patterson Station` | `*** Station` |
| `customer_id` | `CUS000895` | `customer_token`, SHA-256, 64 hex |
| `card_number` | full PAN | `************6075` |

`customer_token` joins customers to orders to `customer_summary`, so per-customer aggregation
survives while identity does not.

Granular values are binned: age into `18-24`, `25-34`, `35-44`, `45-54`, `55+`; payment amount into a
`spending_bucket` of `Low`, `Medium`, `High`, `Very High`.

Silver, as Parquet:

| file | columns |
|---|---|
| `customers_secure` | customer_name, email, phone, address, city, state, signup_date, customer_token, age, age_band |
| `orders_clean` | order_id, product_id, quantity, unit_price, total_amount, order_date, status, payment_method, customer_token |
| `payments_secure` | payment_id, order_id, card_number, amount, payment_date, payment_status, spending_bucket |
| `products_clean` | product_id, product_name, category, cost_price, selling_price |

`secure/` holds the same records as CSV; `silver/` is the Parquet the Gold layer reads. Products carry
no PII and pass through untouched.

### Gold

Five aggregates, all built from Silver, so none of them can expose an identity.

| file | grain | columns |
|---|---|---|
| `sales_summary` | product | product_id, product_name, category, total_orders, total_quantity_sold, total_revenue, avg_order_value |
| `customer_summary` | token | customer_token, age_band, city, state, total_orders, total_spent, avg_order_value |
| `product_summary` | category | category, total_orders, total_units_sold, total_revenue |
| `category_revenue` | category | category, category_revenue |
| `monthly_revenue` | month | order_month, monthly_revenue |

`customer_summary` is keyed on the token and carries only age band, city and state, so customers can
be segmented and ranked without being resolved to people.

## Access

`secure/`, `silver/` and `gold/` are what analysts get. `raw/`, `bronze/`, `clean/` and everything in
`retail_db` still hold unprotected identities and card data, and belong to the pipeline's service
principal alone.

## Loose ends

The scripts write `raw/` and `clean/`, but the snapshot also carries a `bronze/` directory holding the
same schema as `raw/`, a landing copy from an earlier run. The code and the directory layout
disagree; settle it when the missing notebooks are exported.

`data_generation.py` calls `random.seed(42)` but never `Faker.seed()`. The stdlib draws (categories,
quantities, prices, status) are reproducible; everything Faker produces (names, emails, addresses,
dates) differs on every run. Seed both if you want a stable dataset to test the masking layer against.

All data is synthetic Faker output. No real customer data is in this repository.
