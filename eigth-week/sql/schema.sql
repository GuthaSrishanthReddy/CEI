DROP VIEW IF EXISTS v_revenue;
DROP VIEW IF EXISTS v_line;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS customers;

PRAGMA foreign_keys = ON;

CREATE TABLE customers (
  customer_id TEXT PRIMARY KEY,
  customer_name TEXT NOT NULL,
  email TEXT NOT NULL,
  registration_date TEXT NOT NULL,
  customer_type TEXT NOT NULL,
  region_code TEXT NOT NULL,
  email_valid INTEGER NOT NULL CHECK (email_valid IN (0, 1))
);

CREATE TABLE products (
  product_id TEXT PRIMARY KEY,
  product_name TEXT NOT NULL,
  category TEXT NOT NULL,
  subcategory TEXT NOT NULL,
  cost_price REAL NOT NULL CHECK (cost_price > 0)
);

CREATE TABLE orders (
  order_id TEXT PRIMARY KEY,
  customer_id TEXT NULL REFERENCES customers(customer_id),
  order_date TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('DELIVERED', 'SHIPPED', 'PLACED', 'CANCELLED', 'RETURNED')),
  region_code TEXT NOT NULL,
  is_guest INTEGER NOT NULL CHECK (is_guest IN (0, 1))
);

CREATE TABLE order_items (
  item_id TEXT PRIMARY KEY,
  order_id TEXT NOT NULL REFERENCES orders(order_id),
  product_id TEXT NOT NULL REFERENCES products(product_id),
  quantity INTEGER NOT NULL CHECK (quantity <> 0),
  unit_price REAL NOT NULL CHECK (unit_price > 0),
  discount_percent REAL NOT NULL CHECK (discount_percent BETWEEN 0 AND 100)
);

CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_orders_date ON orders(order_date);
CREATE INDEX idx_items_order ON order_items(order_id);
CREATE INDEX idx_items_product ON order_items(product_id);

CREATE VIEW v_line AS
SELECT
  oi.item_id,
  oi.order_id,
  oi.product_id,
  o.customer_id,
  o.order_date,
  o.status,
  o.region_code,
  o.is_guest,
  p.category,
  p.subcategory,
  p.product_name,
  p.cost_price,
  oi.quantity,
  oi.unit_price,
  oi.discount_percent,
  substr(o.order_date, 1, 10) AS order_day,
  substr(o.order_date, 1, 7) AS order_month,
  oi.quantity * oi.unit_price * (1 - oi.discount_percent / 100.0) AS net_revenue,
  CASE WHEN oi.quantity > 0 THEN oi.quantity * oi.unit_price * (1 - oi.discount_percent / 100.0) ELSE 0 END AS gross_revenue,
  CASE WHEN oi.quantity < 0 THEN -oi.quantity * oi.unit_price * (1 - oi.discount_percent / 100.0) ELSE 0 END AS return_value,
  CASE WHEN oi.quantity < 0 THEN 1 ELSE 0 END AS is_return
FROM order_items oi
JOIN orders o ON o.order_id = oi.order_id
JOIN products p ON p.product_id = oi.product_id;

CREATE VIEW v_revenue AS
SELECT * FROM v_line WHERE status NOT IN ('CANCELLED');
