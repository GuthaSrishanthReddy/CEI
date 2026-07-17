# Databricks notebook source
#Load all the tables 
customers = spark.read.option("header", True).option("inferSchema", True) \
    .csv("/Volumes/workspace/default/retail_data/raw/customers")

products = spark.read.option("header", True).option("inferSchema", True) \
    .csv("/Volumes/workspace/default/retail_data/raw/products")

orders = spark.read.option("header", True).option("inferSchema", True) \
    .csv("/Volumes/workspace/default/retail_data/raw/orders")

payments = spark.read.option("header", True).option("inferSchema", True) \
    .csv("/Volumes/workspace/default/retail_data/raw/payments")


# COMMAND ----------

#schemas
customers.printSchema()
customers.show(5)

products.printSchema()
orders.printSchema()
payments.printSchema()

# COMMAND ----------

#Null values check
from pyspark.sql.functions import col, sum as spark_sum, when

def null_report(df, name):
    print(f"\n{name} — Null Counts:")
    df.select([
        spark_sum(when(col(c).isNull(), 1).otherwise(0)).alias(c)
        for c in df.columns
    ]).show()

null_report(customers, "customers")
null_report(products, "products")
null_report(orders, "orders")
null_report(payments, "payments")

# COMMAND ----------

#Duplicate Values check
def duplicate_report(df, name, key_col):
    total = df.count()
    distinct_rows = df.distinct().count()
    distinct_keys = df.select(key_col).distinct().count()
    print(f"{name}: total={total}, distinct_rows={distinct_rows}, "
          f"exact_duplicates={total - distinct_rows}, "
          f"duplicate_{key_col}={total - distinct_keys}")

duplicate_report(customers, "customers", "customer_id")
duplicate_report(products, "products", "product_id")
duplicate_report(orders, "orders", "order_id")
duplicate_report(payments, "payments", "payment_id")

# COMMAND ----------

# Negative prices check
invalid_prices = products.filter((col("cost_price") < 0) | (col("selling_price") < 0))
print("Invalid product prices:", invalid_prices.count())

# Zero/negative quantity check
invalid_qty = orders.filter(col("quantity") <= 0)
print("Invalid order quantities:", invalid_qty.count())

# Invalid emails check
invalid_emails = customers.filter(~col("email").contains("@"))
print("Invalid emails:", invalid_emails.count())

# Future signup dates check
from pyspark.sql.functions import current_date
future_signups = customers.filter(col("signup_date") > current_date())
print("Future signup dates:", future_signups.count()) 

# COMMAND ----------

# Orders with invalid customers
orphan_order_customers = orders.join(customers, "customer_id", "left_anti")
print("Orders with invalid customer_id:", orphan_order_customers.count())

# Orders with invalid products
orphan_order_products = orders.join(products, "product_id", "left_anti")
print("Orders with invalid product_id:", orphan_order_products.count())

# Payments with invalid orders
orphan_payments = payments.join(orders, "order_id", "left_anti")
print("Payments with invalid order_id:", orphan_payments.count())


# COMMAND ----------

#Orders grouped by payement status
orders.groupBy("status").count().show()
orders.groupBy("status").agg({"total_amount": "sum"}).show()

# COMMAND ----------

#Finally Quality Summary
from pyspark.sql import Row
from pyspark.sql.functions import col, sum as spark_sum, when

def total_null_count(df):
    col_list = df.columns
    expr_list = []
    for c in col_list:
        expr_list.append(spark_sum(when(col(c).isNull(), 1).otherwise(0)).alias(c))
    row = df.select(*expr_list).collect()[0]
    total = 0
    for c in col_list:
        total = total + row[c]
    return total

def duplicate_count(df):
    return df.count() - df.distinct().count()

summary_data = [
    Row(dataset="customers", row_count=customers.count(), total_nulls=total_null_count(customers), exact_duplicates=duplicate_count(customers)),
    Row(dataset="products", row_count=products.count(), total_nulls=total_null_count(products), exact_duplicates=duplicate_count(products)),
    Row(dataset="orders", row_count=orders.count(), total_nulls=total_null_count(orders), exact_duplicates=duplicate_count(orders)),
    Row(dataset="payments", row_count=payments.count(), total_nulls=total_null_count(payments), exact_duplicates=duplicate_count(payments)),
]

quality_summary = spark.createDataFrame(summary_data)
quality_summary.show()

# COMMAND ----------

