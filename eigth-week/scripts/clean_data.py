import os
from datetime import datetime

import pandas as pd


TODAY = datetime.strptime("2026-07-16", "%Y-%m-%d")
ROOT = os.path.dirname(os.path.dirname(__file__))
RAW_DIR = os.path.join(ROOT, "data", "raw")
CLEAN_DIR = os.path.join(ROOT, "data", "cleaned")


def alter_date(value):
    value = str(value).strip()

    try:
        if "-" in value and len(value.split("-")[0]) == 4:
            return datetime.strptime(value, "%Y-%m-%d")
        if "-" in value and len(value.split("-")[0]) == 2:
            return datetime.strptime(value, "%d-%m-%Y")
    except ValueError:
        return pd.NaT

    return pd.NaT


def email_is_valid(email):
    email = str(email)
    return "@" in email and "." in email.split("@")[-1]


def explore_data(name, df):
    print("\n" + name)
    print("Shape:", df.shape)
    print("First 5 rows:")
    print(df.head())
    print("Missing values:")
    print(df.isna().sum())
    print("Duplicate rows:", df.duplicated().sum())


def clean_customers(customers):
    customers = customers.drop_duplicates(subset=["customer_id"]).copy()
    customers["customer_name"] = customers["customer_name"].astype(str).str.strip().str.title()
    customers["email_valid"] = customers["email"].apply(email_is_valid).astype(int)
    return customers


def clean_products(products):
    products = products.drop_duplicates(subset=["product_id"]).copy()
    products["product_name"] = products["product_name"].astype(str).str.strip().str.title()
    products["cost_price"] = pd.to_numeric(products["cost_price"], errors="coerce")
    products = products[products["cost_price"] > 0].copy()
    return products


def clean_orders(orders):
    orders = orders.drop_duplicates(subset=["order_id"]).copy()

    orders["customer_id"] = orders["customer_id"].replace(["", "NULL", "None", "nan"], pd.NA)
    orders["is_guest"] = orders["customer_id"].isna().astype(int)

    orders["order_date"] = orders["order_date"].apply(alter_date)
    orders = orders.dropna(subset=["order_date"]).copy()
    orders = orders[orders["order_date"] <= TODAY].copy()
    orders["order_date"] = orders["order_date"].dt.strftime("%Y-%m-%d")

    return orders


def clean_order_items(order_items, orders, products):
    order_items = order_items.drop_duplicates(subset=["item_id"]).copy()

    order_items["quantity"] = pd.to_numeric(order_items["quantity"], errors="coerce")
    order_items["unit_price"] = pd.to_numeric(order_items["unit_price"], errors="coerce")
    order_items["discount_percent"] = pd.to_numeric(order_items["discount_percent"], errors="coerce")

    order_items = order_items.dropna(subset=["quantity", "unit_price", "discount_percent"]).copy()
    order_items = order_items[order_items["quantity"] != 0].copy()
    order_items = order_items[order_items["unit_price"] > 0].copy()
    order_items = order_items[order_items["discount_percent"] >= 0].copy()
    order_items = order_items[order_items["discount_percent"] <= 100].copy()

    #check if all the products from order_items are present in the actual roducts table
    valid_orders = orders["order_id"].tolist()
    valid_products = products["product_id"].tolist()
    order_items = order_items[order_items["order_id"].isin(valid_orders)].copy()
    order_items = order_items[order_items["product_id"].isin(valid_products)].copy()

    return order_items


def main():
    os.makedirs(CLEAN_DIR, exist_ok=True)

    customers = pd.read_csv(os.path.join(RAW_DIR, "customers.csv"))
    products = pd.read_csv(os.path.join(RAW_DIR, "products.csv"))
    orders = pd.read_csv(os.path.join(RAW_DIR, "orders.csv"))
    order_items = pd.read_csv(os.path.join(RAW_DIR, "order_items.csv"))

    explore_data("customers raw", customers)
    explore_data("products raw", products)
    explore_data("orders raw", orders)
    explore_data("order_items raw", order_items)

    customers_clean = clean_customers(customers)
    products_clean = clean_products(products)
    orders_clean = clean_orders(orders)
    order_items_clean = clean_order_items(order_items, orders_clean, products_clean)

    customers_clean.to_csv(os.path.join(CLEAN_DIR, "customers_clean.csv"), index=False)
    products_clean.to_csv(os.path.join(CLEAN_DIR, "products_clean.csv"), index=False)
    orders_clean.to_csv(os.path.join(CLEAN_DIR, "orders_clean.csv"), index=False)
    order_items_clean.to_csv(os.path.join(CLEAN_DIR, "order_items_clean.csv"), index=False)

    print("\nCleaned CSV files saved")
    print("customers_clean:", len(customers_clean))
    print("products_clean:", len(products_clean))
    print("orders_clean:", len(orders_clean))
    print("order_items_clean:", len(order_items_clean))


if __name__ == "__main__":
    main()
