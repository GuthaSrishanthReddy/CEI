import os
import random
from datetime import datetime, timedelta

import pandas as pd
from faker import Faker


SEED = 42
N_CUSTOMERS = 500
N_PRODUCTS = 500
N_ORDERS = 5000
TODAY = "2026-07-16"

ROOT = os.path.dirname(os.path.dirname(__file__))
RAW_DIR = os.path.join(ROOT, "data", "raw")

fake = Faker()
random.seed(SEED)
Faker.seed(SEED)


def random_date(start_date, end_date):
    start = datetime.strptime(start_date, "%Y-%m-%d")
    end = datetime.strptime(end_date, "%Y-%m-%d")
    days = (end - start).days
    return start + timedelta(days=random.randint(0, days))


def make_customers():
    rows = []
    customer_types = ["REGULAR", "PREMIUM", "VIP"]
    regions = ["NORTH", "SOUTH", "EAST", "WEST", "CENTRAL"]

    for i in range(1, N_CUSTOMERS + 1):
        email = fake.email()

        if random.random() < 0.02:
            email = email.replace("@", "")

        row = {
            "customer_id": "C" + str(i).zfill(4),
            "customer_name": fake.name(),
            "email": email,
            "registration_date": random_date("2023-07-01", "2026-06-30").strftime("%Y-%m-%d"),
            "customer_type": random.choice(customer_types),
            "region_code": random.choice(regions),
        }
        rows.append(row)

    return pd.DataFrame(rows)


def make_products():
    rows = []
    categories = {
        "Electronics": ["Laptop", "Phone", "Tablet", "Camera"],
        "Home": ["Kitchen", "Furniture", "Decor", "Storage"],
        "Clothing": ["Shirt", "Shoes", "Jacket", "Pants"],
        "Books": ["Fiction", "Business", "Science", "Kids"],
    }

    for i in range(1, N_PRODUCTS + 1):
        category = random.choice(list(categories.keys()))
        subcategory = random.choice(categories[category])

        if category == "Electronics":
            cost_price = random.randint(150, 1800)
        elif category == "Home":
            cost_price = random.randint(30, 600)
        elif category == "Clothing":
            cost_price = random.randint(10, 150)
        else:
            cost_price = random.randint(5, 50)

        product_name = subcategory + " " + fake.word().title()

        if random.random() < 0.08:
            product_name = "  " + product_name.upper() + "  "

        row = {
            "product_id": "P" + str(i).zfill(4),
            "product_name": product_name,
            "category": category,
            "subcategory": subcategory,
            "cost_price": cost_price,
        }
        rows.append(row)

    return pd.DataFrame(rows)


def make_orders(customers):
    rows = []
    customer_ids = customers["customer_id"].tolist()
    regions = ["NORTH", "SOUTH", "EAST", "WEST", "CENTRAL"]
    statuses = ["DELIVERED", "SHIPPED", "PLACED", "CANCELLED", "RETURNED"]

    for i in range(1, N_ORDERS + 1):
        customer_id = random.choice(customer_ids)
        order_date = random_date("2024-01-01", "2026-07-15")

        if random.random() < 0.05:
            customer_id = random.choice(["", "NULL", "None"])

        date_text = order_date.strftime("%Y-%m-%d")

        if random.random() < 0.04:
            date_text = order_date.strftime("%d-%m-%Y")

        if random.random() < 0.005:
            future_date = datetime.strptime(TODAY, "%Y-%m-%d") + timedelta(days=random.randint(1, 60))
            date_text = future_date.strftime("%Y-%m-%d")

        if random.random() < 0.002:
            date_text = "bad-date"

        row = {
            "order_id": "O" + str(i).zfill(6),
            "customer_id": customer_id,
            "order_date": date_text,
            "status": random.choice(statuses),
            "region_code": random.choice(regions),
        }
        rows.append(row)

    orders = pd.DataFrame(rows)
    duplicate_rows = orders.sample(frac=0.005, random_state=SEED)
    orders = pd.concat([orders, duplicate_rows], ignore_index=True)
    return orders


def make_order_items(orders, products):
    rows = []
    product_ids = products["product_id"].tolist()
    product_cost = dict(zip(products["product_id"], products["cost_price"]))
    item_number = 1

    for order_id in orders["order_id"].drop_duplicates():
        number_of_items = random.randint(1, 5)

        for j in range(number_of_items):
            product_id = random.choice(product_ids)
            cost_price = product_cost[product_id]
            unit_price = round(cost_price * random.uniform(1.2, 1.8), 2)
            quantity = random.randint(1, 4)

            if random.random() < 0.03:
                quantity = quantity * -1

            discount = random.choice([0, 5, 10, 15, 20])

            if random.random() < 0.005:
                quantity = 0

            if random.random() < 0.005:
                discount = random.randint(101, 140)

            item_order_id = order_id
            if random.random() < 0.01:
                item_order_id = "O_ORPHAN_" + str(item_number)

            row = {
                "item_id": "I" + str(item_number).zfill(7),
                "order_id": item_order_id,
                "product_id": product_id,
                "quantity": quantity,
                "unit_price": unit_price,
                "discount_percent": discount,
            }
            rows.append(row)
            item_number = item_number + 1

    items = pd.DataFrame(rows)
    duplicate_rows = items.sample(frac=0.005, random_state=SEED)
    items = pd.concat([items, duplicate_rows], ignore_index=True)
    return items


def main():
    os.makedirs(RAW_DIR, exist_ok=True)

    customers = make_customers()
    products = make_products()
    orders = make_orders(customers)
    order_items = make_order_items(orders, products)

    customers.to_csv(os.path.join(RAW_DIR, "customers.csv"), index=False)
    products.to_csv(os.path.join(RAW_DIR, "products.csv"), index=False)
    orders.to_csv(os.path.join(RAW_DIR, "orders.csv"), index=False)
    order_items.to_csv(os.path.join(RAW_DIR, "order_items.csv"), index=False)

    print("Raw CSV files created")
    print("customers:", len(customers))
    print("products:", len(products))
    print("orders:", len(orders))
    print("order_items:", len(order_items))


if __name__ == "__main__":
    main()
