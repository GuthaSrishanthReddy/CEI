# Databricks notebook source
customers_spark = spark.read.option("header", True).option("inferSchema", True) \
    .csv("/Volumes/workspace/default/retail_data/raw/customers")

products_spark = spark.read.option("header", True).option("inferSchema", True) \
    .csv("/Volumes/workspace/default/retail_data/raw/products")

orders_spark = spark.read.option("header", True).option("inferSchema", True) \
    .csv("/Volumes/workspace/default/retail_data/raw/orders")

payments_spark = spark.read.option("header", True).option("inferSchema", True) \
    .csv("/Volumes/workspace/default/retail_data/raw/payments")

customers_spark.write.mode("append").saveAsTable("retail_db.customers")
products_spark.write.mode("append").saveAsTable("retail_db.products")
orders_spark.write.mode("append").saveAsTable("retail_db.orders")
payments_spark.write.mode("append").saveAsTable("retail_db.payments")

print("Data loaded.")

# COMMAND ----------

# MAGIC %sql
# MAGIC SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM retail_db.customers
# MAGIC UNION ALL
# MAGIC SELECT 'products', COUNT(*) FROM retail_db.products
# MAGIC UNION ALL
# MAGIC SELECT 'orders', COUNT(*) FROM retail_db.orders
# MAGIC UNION ALL
# MAGIC SELECT 'payments', COUNT(*) FROM retail_db.payments;

# COMMAND ----------

