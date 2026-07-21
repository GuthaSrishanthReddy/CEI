# Databricks notebook source
from faker import Faker
import pandas as pd
import random
from datetime import datetime
from pathlib import Path
import os

#Creating a volume
# spark.sql("""CREATE VOLUME workspace.default.retail_data""")
# dbutils.fs.mkdirs("/Volumes/workspace/default/retail_data/raw")
# dbutils.fs.mkdirs("/Volumes/workspace/default/retail_data/bronze")
# dbutils.fs.mkdirs("/Volumes/workspace/default/retail_data/silver")
# dbutils.fs.mkdirs("/Volumes/workspace/default/retail_data/gold")

fake = Faker()
random.seed(42)

NUM_CUSTOMERS = 1000
NUM_PRODUCTS = 300
NUM_ORDERS = 7000

# Generating fake customers
customers = []
for i in range(1, NUM_CUSTOMERS + 1):
    customer = {
        "customer_id": f"CUS{i:06d}",
        "customer_name": fake.name(),
        "email": fake.email(),
        "phone": fake.msisdn()[:10],
        "dob": fake.date_of_birth(minimum_age=18, maximum_age=65),
        "address": fake.street_address(),
        "city": fake.city(),
        "state": fake.state(),
        "signup_date": fake.date_between(start_date="-5y", end_date="today")
    }

    customers.append(customer)

# Making a DataFrame
customers = pd.DataFrame(customers)

# Save to CSV
spark.createDataFrame(customers).write \
    .mode("overwrite") \
    .option("header", True) \
    .csv("/Volumes/workspace/default/retail_data/raw/customers")

products = []
categories = [
    "Electronics", "Fashion", "Grocery", "Books",
    "Sports", "Beauty", "Home"
]
product_names = [
    "Laptop", "Smartphone", "Headphones", "Monitor", "Keyboard",
    "Mouse", "T-Shirt", "Shoes", "Watch", "Backpack",
    "Rice", "Cooking Oil", "Coffee", "Novel", "Notebook",
    "Football", "Cricket Bat", "Face Wash", "Perfume", "Mixer Grinder"
]

for i in range(1, NUM_PRODUCTS + 1):
    cost_price = round(random.uniform(50, 20000), 2)
    margin = random.uniform(1.15, 1.6)
    product = {
        "product_id": f"PROD{i:04d}",
        "product_name": random.choice(product_names),
        "category": random.choice(categories),
        "cost_price": cost_price,
        "selling_price": round(cost_price * margin, 2)
    }
    products.append(product)

#saving products data
products = pd.DataFrame(products)
spark.createDataFrame(products).write \
    .mode("overwrite") \
    .option("header", True) \
    .csv("/Volumes/workspace/default/retail_data/raw/products")

orders = []
statuses = ["Delivered", "Shipped", "Cancelled", "Returned", "Pending"]
payment_methods = ["Credit Card", "Debit Card", "UPI", "Net Banking", "COD"]

customer_ids = customers["customer_id"].tolist()
product_ids = products["product_id"].tolist()
product_price_map = dict(zip(products["product_id"], products["selling_price"]))

for i in range(1, NUM_ORDERS + 1):
    prod_id = random.choice(product_ids)
    qty = random.randint(1, 5)
    unit_price = product_price_map[prod_id]
    order = {
        "order_id": f"ORD{i:07d}",
        "customer_id": random.choice(customer_ids),
        "product_id": prod_id,
        "quantity": qty,
        "unit_price": unit_price,
        "total_amount": round(unit_price * qty, 2),
        "order_date": fake.date_between(start_date="-2y", end_date="today"),
        "status": random.choice(statuses),
        "payment_method": random.choice(payment_methods)
    }
    orders.append(order)

#Saving orders data
orders = pd.DataFrame(orders)

spark.createDataFrame(orders).write \
    .mode("overwrite") \
    .option("header", True) \
    .csv("/Volumes/workspace/default/retail_data/raw/orders")

payments = []
payment_statuses = ["Success", "Failed", "Refunded"]
order_ids = orders["order_id"].tolist()

for i, oid in enumerate(order_ids, start=1):
    order_total = orders.loc[orders["order_id"] == oid, "total_amount"].values[0]
    payment = {
        "payment_id": f"PAY{i:07d}",
        "order_id": oid,
        "card_number": fake.credit_card_number(),
        "cvv": fake.credit_card_security_code(),
        "amount": order_total,
        "payment_date": fake.date_between(start_date="-2y", end_date="today"),
        "payment_status": random.choice(payment_statuses)
    }
    payments.append(payment)

#saving payements data
payments = pd.DataFrame(payments)

spark.createDataFrame(payments).write \
    .mode("overwrite") \
    .option("header", True) \
    .csv("/Volumes/workspace/default/retail_data/raw/payments")
