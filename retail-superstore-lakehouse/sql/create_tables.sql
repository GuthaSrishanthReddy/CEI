%sql
CREATE DATABASE IF NOT EXISTS retail_db;
USE retail_db;



CREATE TABLE IF NOT EXISTS retail_db.customers (
    customer_id     STRING NOT NULL,
    customer_name   STRING NOT NULL,
    email           STRING NOT NULL,
    phone           STRING,
    dob             DATE,
    address         STRING,
    city            STRING,
    state           STRING,
    signup_date     DATE,
    CONSTRAINT pk_customers PRIMARY KEY (customer_id)
) USING DELTA;


CREATE TABLE IF NOT EXISTS retail_db.products (
    product_id      STRING NOT NULL,
    product_name    STRING NOT NULL,
    category        STRING NOT NULL,
    cost_price      DECIMAL(10,2) NOT NULL,
    selling_price   DECIMAL(10,2) NOT NULL,
    CONSTRAINT pk_products PRIMARY KEY (product_id)
) USING DELTA;


CREATE TABLE IF NOT EXISTS retail_db.orders (
    order_id        STRING NOT NULL,
    customer_id     STRING NOT NULL,
    product_id      STRING NOT NULL,
    quantity        INT NOT NULL,
    unit_price      DECIMAL(10,2) NOT NULL,
    total_amount    DECIMAL(10,2) NOT NULL,
    order_date      DATE NOT NULL,
    status          STRING NOT NULL,
    payment_method  STRING,
    CONSTRAINT pk_orders PRIMARY KEY (order_id),
    CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id) REFERENCES retail_db.customers(customer_id),
    CONSTRAINT fk_orders_product FOREIGN KEY (product_id) REFERENCES retail_db.products(product_id)
) USING DELTA;


CREATE TABLE IF NOT EXISTS retail_db.payments (
    payment_id      STRING NOT NULL,
    order_id        STRING NOT NULL,
    card_number     STRING,
    cvv             STRING,
    amount          DECIMAL(10,2) NOT NULL,
    payment_date    DATE NOT NULL,
    payment_status  STRING NOT NULL,
    CONSTRAINT pk_payments PRIMARY KEY (payment_id),
    CONSTRAINT fk_payments_order FOREIGN KEY (order_id) REFERENCES retail_db.orders(order_id)
) USING DELTA;