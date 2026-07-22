# Secure Retail Data Lakehouse

Batch pipeline that strips PII and cardholder data out of retail operational data before it reaches
analysts. Records land with full names, street addresses, dates of birth, card numbers and CVVs. The
Gold layer exposes only aggregates, with each customer reduced to an irreversible token.

```
sql/create_tables.sql     Delta DDL for retail_db
scripts/                  the pipeline: four exported .py notebooks and three .ipynb notebooks
data/                     output snapshot pulled down for review; nothing reads it
```

## Running this

Built on Databricks and it only runs there. `scripts/` holds two forms of the same thing: the `.py`
files are notebooks exported and the `.ipynb` files are notebooks proper. Import either through Workspace > Import >
File. They use the injected `spark` and `dbutils` handles (there is no `SparkSession.builder` call
anywhere in the codebase), read and write to a Unity Catalog Volume at
`/Volumes/workspace/default/retail_data/`, and `create_tables.sql` leads with a `%sql` magic. None of
that survives off-cluster.

You need Unity Catalog enabled, a running cluster, `faker` on it (`%pip install faker`), and rights to
create a Volume and database under `workspace.default`. The Volume must exist before anything else
runs; that code sits commented out at the top of [data_generation.py](scripts/data_generation.py#L9-L14).
Uncomment it, run it once, comment it back.

## Order

| | | |
|---|---|---|
| 1 | [sql/create_tables.sql](sql/create_tables.sql) | creates `retail_db` and four Delta tables |
| 2 | [scripts/data_generation.py](scripts/data_generation.py) | synthetic source data into `raw/` |
| 3 | [scripts/bronze_layer.ipynb](scripts/bronze_layer.ipynb) | copies `raw/` into `bronze/` |
| 4 | [scripts/data_loading.py](scripts/data_loading.py) | `raw/` into the Delta tables |
| 5 | [scripts/data_quality.py](scripts/data_quality.py) | profiles `raw/`, writes nothing |
| 6 | [scripts/data_cleaning.py](scripts/data_cleaning.py) | `raw/` into `clean/` |
| 7 | [scripts/silver_layer.ipynb](scripts/silver_layer.ipynb) | masks `clean/` into `silver/` |
| 8 | [scripts/gold_layer.ipynb](scripts/gold_layer.ipynb) | aggregates `silver/` into `gold/` |

The live path to Gold is generation, cleaning, silver, gold: `raw` to `clean` to `silver` to `gold`.
Bronze (step 3), the Delta load (step 4) and the quality report (step 5) are side branches that
nothing downstream reads, so they can be skipped or re-run without affecting Gold.

## The files

**create_tables.sql** builds `retail_db` with customers, products, orders and payments, PK/FK
constraints, Delta throughout. This is the landing schema, so it still declares `dob`, `address`,
`card_number` and `cvv`. The tables are therefore as sensitive as `raw/` and need the same access
restrictions.

**data_generation.py** produces a thousand customers, three hundred products across seven categories,
seven thousand orders spread over two years, and one payment per order, written as headered CSV per
dataset. It generates the worst case deliberately: exact dates of birth, street addresses, card
numbers, CVVs.

**bronze_layer.ipynb** loops the four datasets and rewrites each from `raw/` to `bronze/` unchanged,
same schema and format. It is the medallion landing copy. Nothing in the current code reads `bronze/`
back, so in practice it is a dead branch (see Loose ends).

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
tables from step 4 are a parallel landing target, not an input to cleansing.

### silver_layer.ipynb

Reads `clean/`, applies the security transforms, writes Parquet to `silver/`. This is the layer that
gives the project its name.

Columns are dropped outright: `cvv`, which PCI-DSS forbids retaining at all; `dob`, replaced by a
band; and `customer_id`, replaced by a token.

Direct identifiers are masked. Values below are the actual output in `data/silver/`:

| field | raw | stored | rule |
|---|---|---|---|
| `customer_name` | `Patrick Duran` | `P***` | first character, then `***` |
| `email` | `ortegamatthew@example.org` | `o***@example.org` | first character, then `***@`, then the domain |
| `phone` | `(930) 417-7541` | `(XXX) XXX-7541` | last four digits only |
| `address` | `099 Patterson Station` | `*** Station` | last token only |
| `customer_id` | `CUS000895` | `customer_token` | SHA-256, 64 hex |
| `card_number` | full PAN | `************6075` | twelve stars, then last four |

`customer_token` is `sha2(customer_id, 256)` and is applied to both customers and orders. SHA-256 is
deterministic, so the two sides join, and per-customer aggregation survives while identity does not.

Granular values are binned. Age from `dob`: under 25 is `18-24`, then `25-34`, `35-44`, `45-54`, and
55 or over is `55+`. Payment amount into `spending_bucket`: under 1,000 is `Low`, under 5,000
`Medium`, under 15,000 `High`, otherwise `Very High`.

Silver output, as Parquet:

| file | columns |
|---|---|
| `customers_secure` | customer_name, email, phone, address, city, state, signup_date, customer_token, age, age_band |
| `orders_clean` | order_id, product_id, quantity, unit_price, total_amount, order_date, status, payment_method, customer_token |
| `payments_secure` | payment_id, order_id, card_number, amount, payment_date, payment_status, spending_bucket |
| `products_clean` | product_id, product_name, category, cost_price, selling_price |

Products carry no PII and are written straight through.

### gold_layer.ipynb

Reads `silver/` and writes five aggregates to `gold/`. All are built from Silver, so none can expose
an identity.

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

`silver/` and `gold/` are what analysts get. `raw/`, `bronze/`, `clean/` and everything in `retail_db`
still hold unprotected identities and card data, and belong to the pipeline's service principal alone.


All data is synthetic Faker output. No real customer data is in this repository.
