# Secure Retail Data Lakehouse

A batch data pipeline that acts as a **compliance filter** between raw retail operational data
(e-commerce / POS) and downstream analytics teams. Raw PII and PCI data lands in the lake, and is
progressively hard-dropped, masked, tokenized, and aggregated as it moves through the
**Raw → Bronze → Silver → Gold** layers, so that analysts receive purchase trends without ever
seeing a customer's identity, address, date of birth, or card details.

---

## ⚠️ IMPORTANT: This project runs on Databricks

**This project was built in Databricks and must be executed inside a Databricks workspace.**
It will **not** run as plain local Python. Specifically:

- Every `.py` file in `scripts/` is a **Databricks notebook exported as source** — note the
  `# Databricks notebook source` header and the `# COMMAND ----------` cell separators.
  Import them into your workspace (`Workspace → Import → File`) and they will re-open as notebooks
  with their original cell structure.
- The scripts use the pre-initialized `spark` session and `dbutils` objects, which only exist on a
  Databricks cluster. There is no `SparkSession.builder` call anywhere in this codebase.
- All I/O paths point to a **Unity Catalog Volume**: `/Volumes/workspace/default/retail_data/...`.
- `sql/create_tables.sql` begins with the `%sql` magic command — it is meant to be pasted into a
  Databricks notebook cell, not fed to an external SQL client.
- The `data/` folder in this repo is a **downloaded copy of the pipeline output** for review only.
  The pipeline does not read from or write to it. Running the notebooks regenerates everything
  inside the Volume.

---

## Repository structure

```
retail-superstore-lakehouse/
├── sql/
│   └── create_tables.sql        # Delta table DDL for the retail_db database
├── scripts/                     # Databricks notebooks (exported as .py source)
│   ├── data_generation.py       # 1. Generate synthetic raw retail data
│   ├── data_loading.py          # 2. Load raw CSV into Delta tables
│   ├── data_quality.py          # 3. Profile & validate the raw data
│   └── data_cleaning.py         # 4. Standardize / cleanse the raw data
└── data/                        # Output snapshot pulled down from the Volume (reference only)
    ├── raw/                     # Unmodified generated data (contains full PII + CVV)
    ├── bronze/                  # Ingested landing copy
    ├── clean/                   # Output of data_cleaning.py
    ├── secure/                  # Masked & tokenized data (CSV)
    ├── silver/                  # Masked & tokenized data (Parquet, analytics-ready)
    └── gold/                    # Business aggregates (Parquet)
```

---

## Prerequisites

1. A Databricks workspace with **Unity Catalog** enabled and a running cluster (the outputs in
   this repo were produced on a Photon cluster running DBR with Spark 3.x).
2. The `faker` library installed on the cluster. Add this as the first cell of
   `data_generation.py`, or install it as a cluster library:
   ```python
   %pip install faker
   ```
3. Permission to create a Volume and a database in `workspace.default`.

### One-time setup — create the Volume

The Volume and its directories must exist before anything else runs. This code sits **commented out**
at the top of [data_generation.py](scripts/data_generation.py#L11-L16) — uncomment and run it once:

```python
spark.sql("""CREATE VOLUME workspace.default.retail_data""")
dbutils.fs.mkdirs("/Volumes/workspace/default/retail_data/raw")
dbutils.fs.mkdirs("/Volumes/workspace/default/retail_data/bronze")
dbutils.fs.mkdirs("/Volumes/workspace/default/retail_data/silver")
dbutils.fs.mkdirs("/Volumes/workspace/default/retail_data/gold")
```

---

## Execution sequence

Run the notebooks **in this exact order**. Each step depends on the output of the one before it.

| # | File | Purpose | Reads | Writes |
|---|------|---------|-------|--------|
| 0 | Volume setup cell in `data_generation.py` | Create the Volume + layer directories | — | Volume dirs |
| 1 | [sql/create_tables.sql](sql/create_tables.sql) | Create `retail_db` and the 4 Delta tables | — | `retail_db.*` |
| 2 | [scripts/data_generation.py](scripts/data_generation.py) | Generate synthetic retail data with Faker | — | `raw/` |
| 3 | [scripts/data_loading.py](scripts/data_loading.py) | Ingest raw CSV into the Delta tables | `raw/` | `retail_db.*` |
| 4 | [scripts/data_quality.py](scripts/data_quality.py) | Profile & validate the raw data | `raw/` | console report |
| 5 | [scripts/data_cleaning.py](scripts/data_cleaning.py) | Cast types, dedupe, standardize | `raw/` | `clean/` |
| 6 | *PII masking / Silver notebook* — **see gap note below** | Hard-drop, mask, tokenize, bin | `clean/` | `secure/`, `silver/` |
| 7 | *Gold aggregation notebook* — **see gap note below** | Build business aggregates | `silver/` | `gold/` |

> Step 4 (`data_quality.py`) is a read-only report — it writes nothing and can be skipped or re-run
> at any time without affecting the pipeline.

---

## What each file does

### 1. `sql/create_tables.sql`

Creates the `retail_db` database and four Delta tables with primary/foreign key constraints:

| Table | Key columns | Sensitive columns present at this layer |
|-------|-------------|------------------------------------------|
| `customers` | `customer_id` (PK) | `customer_name`, `email`, `phone`, `dob`, `address` |
| `products` | `product_id` (PK) | — |
| `orders` | `order_id` (PK), FK → customers, products | `customer_id` |
| `payments` | `payment_id` (PK), FK → orders | `card_number`, `cvv` |

This is the **landing schema** — it deliberately still carries raw PII and PCI columns, because the
whole point of the pipeline is that this data arrives unprotected and gets filtered downstream.
Nothing that reads these tables should ever be exposed to analysts.

**How to run it:** paste the file's contents into a Databricks notebook cell (the `%sql` magic is
already on line 1), or copy the DDL into a SQL Warehouse query editor without the magic line.

### 2. `scripts/data_generation.py`

Generates the synthetic source dataset using `Faker` with `random.seed(42)` for reproducibility.

| Dataset | Volume | Notable generated fields |
|---------|--------|--------------------------|
| customers | 1,000 | name, email, phone, **date of birth**, street address, city, state, signup date |
| products | 300 | name, category (7 categories), cost price, selling price (1.15–1.6× margin) |
| orders | 7,000 | customer/product FK, quantity 1–5, unit price, total amount, order date (last 2 yrs), status, payment method |
| payments | 7,000 | one per order — **credit card number**, **CVV**, amount, payment date, status |

Each dataset is built as a pandas DataFrame, converted with `spark.createDataFrame(...)`, and written
as headered CSV to `/Volumes/workspace/default/retail_data/raw/<dataset>`.

This step intentionally produces the *worst-case* input: full names, exact DOBs, home addresses, live
card numbers, and CVVs — precisely the data the rest of the pipeline exists to neutralize.

### 3. `scripts/data_loading.py`

Reads all four raw CSV directories with `header=True, inferSchema=True` and appends them into the
Delta tables created in step 1, then runs a `%sql` cell that prints a row count per table so you can
confirm the load.

> **⚠️ Re-run warning:** this notebook uses `.mode("append")`. Running it twice duplicates every row.
> Either truncate the tables first, or change the mode to `overwrite`, before re-running.

### 4. `scripts/data_quality.py`

A read-only profiling and validation report over the **raw** layer. It does not modify or write data —
it exists to prove what condition the incoming data is in before cleansing. Checks performed:

- **Schema inspection** — `printSchema()` for all four datasets plus a sample of `customers`.
- **Null counts** — per-column null totals for each dataset.
- **Duplicate detection** — total rows vs. distinct rows vs. distinct primary keys.
- **Business rules** — negative `cost_price` / `selling_price`, non-positive order `quantity`,
  emails missing `@`, signup dates in the future.
- **Referential integrity** — `left_anti` joins finding orders with an unknown `customer_id` or
  `product_id`, and payments with an unknown `order_id`.
- **Distribution** — order counts and revenue grouped by order status.
- **Summary table** — a Spark DataFrame with row count, total nulls, and exact duplicates per dataset.

### 5. `scripts/data_cleaning.py`

Standardizes the raw data and writes the result to the `clean/` directory. Transformations, in order:

1. **Type casting** — `dob` and `signup_date` → `DATE`; `order_date` → `DATE`; `payment_date` → `DATE`.
2. **Deduplication** — `dropDuplicates()` on each table's primary key.
3. **Null handling** — fill missing `phone` and `address` with `"Not Provided"`; drop orders missing
   `order_id`, `customer_id`, or `product_id`.
4. **Text standardization** — `trim` + `initcap` on customer name, city, state, product name, and
   category; `trim` on address.
5. **Phone formatting** — strip all non-digits, then reformat to `(XXX) XXX-XXXX`.
6. **Email validation** — flag rows against `^[\w\.-]+@[\w\.-]+\.\w+$`, print the invalid count, and
   drop the failures.
7. **Verification** — print the surviving row count for each dataset.
8. **Write** — headered CSV to `/Volumes/workspace/default/retail_data/clean/<dataset>`.

Note this step reads from `raw/`, not from the Delta tables — the Delta tables from step 3 are a
parallel landing target, not an input to cleansing.

---

## ⚠️ Gap: the masking, Silver, and Gold code is not in this repo

**Steps 6 and 7 of the sequence have no committed source code.** The repo contains only the four
notebooks above plus the DDL, yet `data/secure/`, `data/silver/`, and `data/gold/` are all fully
populated with their outputs. Those notebooks were written and executed in the Databricks workspace
but were never exported into this repository.

**To make this project fully reproducible, export the masking and Gold notebooks from your Databricks
workspace into `scripts/` and commit them.** Until then, steps 1–5 can be re-run end to end, but the
security layer that gives the project its name cannot.

The sections below document what those missing notebooks **did**, reconstructed by inspecting their
committed output files. Treat this as a specification for re-creating or verifying them — not as a
description of code you can currently run.

### Step 6 — PII masking → `secure/` and `silver/`

Applies the three protection strategies from the problem statement:

**Hard-drop** — columns physically removed and never written downstream:

| Column | Dropped from | Reason |
|--------|--------------|--------|
| `cvv` | `payments` | PCI-DSS prohibits storing CVV entirely |
| `dob` | `customers` | Exact birth date is a direct identifier; replaced by `age_band` |
| `customer_id` | `customers`, `orders` | Replaced by the surrogate token |

**Mask & tokenize** — verified against `data/secure/customers/`:

| Field | Raw value | Protected value |
|-------|-----------|-----------------|
| `customer_name` | `Patrick Duran` | `P***` |
| `email` | `ortegamatthew@example.org` | `o***@example.org` |
| `phone` | `(930) 417-7541` | `(XXX) XXX-7541` |
| `address` | `099 Patterson Station` | `*** Station` |
| `customer_id` | `CUS000895` | `customer_token` — SHA-256 (64 hex chars) |
| `card_number` | full PAN | `************6075` — last 4 digits only |

The `customer_token` is a one-way SHA-256 hash. It is joinable across `customers`, `orders`, and the
Gold layer, so analysts can still compute per-customer metrics, but it cannot be reversed to an identity.

**Bin & aggregate** — granular values replaced by ranges:

| Feature | Derived from | Values |
|---------|--------------|--------|
| `age` / `age_band` | `dob` | `18-24`, `25-34`, `35-44`, `45-54`, `55+` |
| `spending_bucket` | payment `amount` | `Low`, `Medium`, `High`, `Very High` |

**Resulting Silver schemas** (Parquet, in `data/silver/`):

| File | Columns |
|------|---------|
| `customers_secure.parquet` | `customer_name`, `email`, `phone`, `address`, `city`, `state`, `signup_date`, `customer_token`, `age`, `age_band` |
| `orders_clean.parquet` | `order_id`, `product_id`, `quantity`, `unit_price`, `total_amount`, `order_date`, `status`, `payment_method`, `customer_token` |
| `payments_secure.parquet` | `payment_id`, `order_id`, `card_number`, `amount`, `payment_date`, `payment_status`, `spending_bucket` |
| `products_clean.parquet` | `product_id`, `product_name`, `category`, `cost_price`, `selling_price` |

`data/secure/` holds the same masked records in CSV form; `data/silver/` is the Parquet version that
the Gold layer reads. Products carry no PII, so `products_clean` passes through unchanged.

### Step 7 — Gold aggregates

Five business aggregates written as Parquet to `data/gold/`. Every one of them is built from the
Silver layer, so no aggregate can expose an identity:

| File | Grain | Columns |
|------|-------|---------|
| `sales_summary.parquet` | per product | `product_id`, `product_name`, `category`, `total_orders`, `total_quantity_sold`, `total_revenue`, `avg_order_value` |
| `customer_summary.parquet` | per tokenized customer | `customer_token`, `age_band`, `city`, `state`, `total_orders`, `total_spent`, `avg_order_value` |
| `product_summary.parquet` | per category | `category`, `total_orders`, `total_units_sold`, `total_revenue` |
| `category_revenue.parquet` | per category | `category`, `category_revenue` |
| `monthly_revenue.parquet` | per month | `order_month`, `monthly_revenue` |

Note that `customer_summary` is keyed on `customer_token` and carries only `age_band` plus
city/state — an analyst can segment and rank customers without ever resolving one to a person.

---

## Layer reference

| Layer | Path | Format | Contains PII? |
|-------|------|--------|---------------|
| **Raw** | `raw/` | CSV | 🔴 Yes — full names, emails, DOB, addresses, card numbers, **CVV** |
| **Bronze** | `bronze/` | CSV | 🔴 Yes — landing copy, same schema as raw |
| **Clean** | `clean/` | CSV | 🔴 Yes — standardized but not yet masked |
| **Secure** | `secure/` | CSV | 🟢 No — masked & tokenized |
| **Silver** | `silver/` | Parquet | 🟢 No — masked & tokenized, analytics-ready |
| **Gold** | `gold/` | Parquet | 🟢 No — aggregates only |

**Access control:** only `secure/`, `silver/`, and `gold/` should be exposed to data scientists and
business analysts. `raw/`, `bronze/`, `clean/`, and the `retail_db` Delta tables all still contain
unprotected identities and card data, and should be restricted to the pipeline's service principal.

---

## Notes and known issues

- **Naming mismatch between code and data.** The scripts write to `raw/` and `clean/`, but the
  committed `data/` snapshot also contains a `bronze/` directory holding the same schema as `raw/`.
  Bronze appears to be a landing copy of raw made during an earlier run. Align the directory names
  when you export the missing notebooks.
- **`data_loading.py` appends.** See the re-run warning above — it will duplicate rows on a second run.
- **`create_tables.sql` still declares `cvv` and `card_number`.** That is correct for the landing
  layer, but it means the Delta tables in `retail_db` are as sensitive as `raw/`. They must be
  access-restricted, and the Silver layer must be rebuilt from `clean/` rather than from these tables.
- **The generated data is synthetic.** All names, emails, addresses, and card numbers come from
  `Faker` — no real customer data is present anywhere in this repository.
