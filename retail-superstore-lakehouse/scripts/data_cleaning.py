# Databricks notebook source
from pyspark.sql.functions import *

#load data
customers = spark.read.option("header", True).option("inferSchema", True) \
    .csv("/Volumes/workspace/default/retail_data/raw/customers")

products = spark.read.option("header", True).option("inferSchema", True) \
    .csv("/Volumes/workspace/default/retail_data/raw/products")

orders = spark.read.option("header", True).option("inferSchema", True) \
    .csv("/Volumes/workspace/default/retail_data/raw/orders")

payments = spark.read.option("header", True).option("inferSchema", True) \
    .csv("/Volumes/workspace/default/retail_data/raw/payments")

#TypeCasting
customers = customers.withColumn("dob", to_date(col("dob"))) \
                      .withColumn("signup_date", to_date(col("signup_date")))

orders = orders.withColumn("order_date", to_date(col("order_date")))

payments = payments.withColumn("payment_date", to_date(col("payment_date")))

#Duplicates Removal
customers = customers.dropDuplicates(["customer_id"])
products = products.dropDuplicates(["product_id"])
orders = orders.dropDuplicates(["order_id"])
payments = payments.dropDuplicates(["payment_id"])

#Handle Na
customers = customers.na.fill({"phone": "Not Provided", "address": "Not Provided"})
orders = orders.na.drop(subset=["order_id", "customer_id", "product_id"])  

#Formatting Names
customers = customers.withColumn("customer_name", trim(initcap(col("customer_name"))))
customers = customers.withColumn("city", trim(initcap(col("city"))))
customers = customers.withColumn("state", trim(initcap(col("state"))))
customers = customers.withColumn("address", trim(col("address")))

products = products.withColumn("product_name", trim(initcap(col("product_name"))))
products = products.withColumn("category", trim(initcap(col("category"))))

#Formatting Phone numbers

customers = customers.withColumn("phone", regexp_replace(col("phone"), "[^0-9]", ""))
customers = customers.withColumn(
    "phone",
    concat(
        lit("("), substring(col("phone"), 1, 3), lit(") "),
        substring(col("phone"), 4, 3), lit("-"),
        substring(col("phone"), 7, 4)
    )
)

#Validating and dropping invalid emails
customers = customers.withColumn(
    "email_valid",
    col("email").rlike(r"^[\w\.-]+@[\w\.-]+\.\w+$")
)

invalid_email_count = customers.filter(col("email_valid") == False).count()
print("Invalid emails found:", invalid_email_count)

customers = customers.filter(col("email_valid") == True).drop("email_valid")

#Verifying the row counts
print("customers:", customers.count())
print("products:", products.count())
print("orders:", orders.count())
print("payments:", payments.count())

#Save back the cleaned data
customers.write.mode("overwrite").option("header", True) \
    .csv("/Volumes/workspace/default/retail_data/clean/customers")

products.write.mode("overwrite").option("header", True) \
    .csv("/Volumes/workspace/default/retail_data/clean/products")

orders.write.mode("overwrite").option("header", True) \
    .csv("/Volumes/workspace/default/retail_data/clean/orders")

payments.write.mode("overwrite").option("header", True) \
    .csv("/Volumes/workspace/default/retail_data/clean/payments")

print("Cleaned datasets saved.")

