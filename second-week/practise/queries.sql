-- ====================================================================    SECTION A    ========================================================================================

-- Q1. Write a query to display all columns and rows from the customer's table. 
select * from customers;


-- Q2. Retrieve only the first_name, last_name, and city of all customers. 
select first_name, last_name, city from customers;


-- Q3. List all unique categories available in the products table. 
select distinct category from products;


-- Q4. Identify the Primary Key of each table in the schema. Explain why a Primary Key must be unique and NOT NULL. 
-- customers ---> customer_id
-- products ---> product_id
-- orders ---> order_id
-- order_items ---> item_id
-- Primary keys must be UNIQUE and NOT NULL as they are used to identify every single row uniquely. PKs are used to maintain integrity between the tables


-- Q5. What constraints are applied to the email column in the customers table? What would happen if you tried to insert a duplicate email? 
-- The email value cant be empty/null(NOT NULL) and it's marked as UNIQUE so we can't duplicate the email field values. If a duplicate value is tried to be inserted then SQL throws an Error.


-- Q6. Try inserting a product with unit_price = -50. What happens and which constraint prevents it? Write both the INSERT statement and explain the error. 
INSERT INTO products VALUES ( 209, 'Test Product', 'Electronics', 'TestBrand', -50, 100 );
-- error is thrown if this query is executed
-- Error Code: 3819. Check constraint 'products_chk_1' is violated.	0.016 sec


-- ====================================================================    SECTION B    ========================================================================================

-- Q7. Retrieve all orders with status = 'Delivered'. 
SELECT * FROM orders WHERE status = 'Delivered';


-- Q8. Find all products in the 'Electronics' category with a unit_price greater than ₹2000. 
SELECT * FROM products WHERE category = 'Electronics' AND unit_price > 2000;


-- Q9. List all customers who joined in the year 2024 and belong to the state 'Maharashtra'. 
SELECT * FROM customers WHERE state = 'Maharashtra' AND join_date BETWEEN '2024-01-01' AND '2024-12-31';


-- Q10. Find all orders placed between '2024-08-10' and '2024-08-25' (inclusive) that are NOT cancelled. 
SELECT * FROM orders 
WHERE order_date BETWEEN '2024-08-10' AND '2024-08-25' 
AND status <> 'Cancelled';


-- Q11. Explain what the index idx_orders_date does. How would it improve the performance of a query that filters orders by order_date? Write a sample query that would benefit from this index. 
-- The index idx_orders_date creates a sorted structure on the order_date column which helps in faster searching and filtering.
SELECT *
FROM orders
WHERE order_date BETWEEN '2024-08-01' AND '2024-08-15';


-- Q12. If you run: SELECT * FROM customers WHERE YEAR(join_date) = 2024; — would the index on join_date be used? Explain why or why not, and rewrite the query to be index-friendly (SARGable)
-- As YEAR() function is being used to find join_date, using an index on join_date would be useless.
SELECT * FROM customers WHERE join_date >= '2024-01-01' AND join_date < '2025-01-01';
-- this would be a SARGable index friendly query


-- ====================================================================    SECTION C    ========================================================================================


-- Q13. Count the total number of orders in the orders table. 
SELECT COUNT(*) AS `Total orders` FROM orders;


-- Q14. Find the total revenue (SUM of total_amount) from all 'Delivered' orders. 
SELECT SUM(total_amount) AS total_revenue
FROM orders
WHERE status = 'Delivered';


-- Q15. Calculate the average unit_price of products in each category. 
SELECT category, AVG(unit_price) AS avg_price 
FROM products 
GROUP BY category;


-- Q16. For each order status, find the count of orders and the total revenue. Sort the result by total revenue in descending order. 
SELECT status, COUNT(*) AS total_orders, SUM(total_amount) AS total_revenue
FROM orders
GROUP BY status
ORDER BY total_revenue DESC;


-- Q17. Find the most expensive (MAX) and cheapest (MIN) product in each category. 
SELECT category, MAX(unit_price) AS most_expensive, MIN(unit_price) AS cheapest 
FROM products 
GROUP BY category;


-- Q18. List all product categories where the average unit_price is greater than ₹2000. (Hint: Use HAVING clause) 
SELECT category, AVG(unit_price) AS avg_price
FROM products
GROUP BY category
HAVING AVG(unit_price) > 2000;


-- ====================================================================    SECTION D    ========================================================================================


-- Q19. Write an INNER JOIN query to display each order along with the customer's first_name and last_name. Show: order_id, order_date, first_name, last_name, total_amount. 
SELECT o.order_id, o.order_date, c.first_name, c.last_name, o.total_amount 
FROM orders o INNER JOIN customers c 
ON o.customer_id = c.customer_id;


-- Q20. Using a LEFT JOIN, list ALL customers and their orders (if any). Customers with no orders should still appear with NULL values for order columns. 
SELECT c.customer_id, c.first_name, c.last_name, o.order_id, o.order_date, o.total_amount 
FROM customers c LEFT JOIN orders o 
ON c.customer_id = o.customer_id;


-- Q21. Write a query using JOINs across three tables (orders → order_items → products) to show: order_id, product_name, quantity, unit_price, and discount_pct for each order item. 
SELECT o.order_id, p.product_name, oi.quantity, oi.unit_price, oi.discount_pct 
FROM orders o JOIN order_items oi 
ON o.order_id = oi.order_id 
JOIN products p 
ON oi.product_id = p.product_id;

-- Q22. Explain the difference between LEFT JOIN and RIGHT JOIN with an example from this schema. When would you use a FULL OUTER JOIN? 

-- LEFT JOIN return All rows from the left table and only the Matching rows from the right table
SELECT c.first_name,
o.order_id
FROM customers c
LEFT JOIN orders o
ON c.customer_id = o.customer_id;

-- RIGHT JOIN return All rows from the right table and only the Matching rows from the left table
SELECT c.first_name, o.order_id 
FROM customers c 
RIGHT JOIN orders o 
ON c.customer_id = o.customer_id;

-- FULL OUTER JOIN  returns all the rows from both the tables, if any row is not matching they will be filled with NULL.

-- Q23. Identify all Foreign Key relationships in the schema. Explain what would happen if you tried to insert an order with customer_id = 999 (which doesn't exist in customers).

-- FOREIGN KEY RELATIONS:
-- orders ---> customer_id(customers)
-- order_items ---> order_id(orders)
-- order_items ---> product_id(products)
-- if an order with customer_id 99 is tried to be inserted in ORDERS table, then SQL throws an error  --> Error Code: 1452. Cannot add or update a child row: a foreign key constraint
INSERT INTO orders VALUES (1011, 999, '2024-09-01', 'Pending', 2500);


-- ====================================================================    SECTION E    ========================================================================================

-- Q24. Write a query using CASE to classify products into price tiers:
-- 'Budget'    → unit_price < 1000
-- 'Mid-Range' → unit_price BETWEEN 1000 AND 3000
-- 'Premium'   → unit_price > 3000

SELECT product_name, unit_price,
CASE
WHEN unit_price < 1000 THEN 'Budget'
WHEN unit_price BETWEEN 1000 AND 3000 THEN 'Mid-Range'
ELSE 'Premium'
END AS price_tier
FROM products;


-- Q25. Using a CASE statement inside an aggregate function, count how many orders are 'Delivered' vs 'Not Delivered' (all other statuses). Display the result in a single row.

SELECT
SUM(CASE
WHEN status = 'Delivered' THEN 1
ELSE 0
END) AS delivered_orders,

SUM(CASE
WHEN status <> 'Delivered' THEN 1
ELSE 0
END) AS not_delivered_orders
FROM orders;


-- Q26. Explain each letter of ACID:
-- A – Atomicity
-- C – Consistency
-- I – Isolation
-- D – Durability

-- Atomicity:
-- Every individual transaction is considered as a single unit either the transaction completly succeeds for fails completly.

-- Consistency:
-- The database must always be in a vaild state and shouldn't violate any constraints.

-- Isolation:
-- As every Transaction is considered to be individual noe two transactions must interfere with each other.

-- Durability:
-- Once the transaction is committed, it's stored permanantly and records will be available even if the system crashes.

-- Example (Bank Transfer):
-- When transferring money from Account A to Account B:
-- Money is deducted from Account A.
-- Money is added to Account B.
-- If any step fails, the entire transaction is rolled back.
-- This ensures data consistency and reliability.

-- Q27. Write a SQL transaction that performs all operations atomically.

START TRANSACTION;

-- Step 1: Insert new order
INSERT INTO orders
VALUES (
1011,
102,
CURDATE(),
'Pending',
1598.00
);

-- Step 2: Insert order items
INSERT INTO order_items
VALUES
(5016, 1011, 202, 1, 799.00, 0),
(5017, 1011, 208, 1, 599.00, 0);

-- Step 3: Update stock quantities
UPDATE products
SET stock_qty = stock_qty - 1
WHERE product_id = 202;

UPDATE products
SET stock_qty = stock_qty - 1
WHERE product_id = 208;

-- Step 4: if all the steps are executed success fully then commit transaction
COMMIT;

-- If any statement fails then rollback the transaction;
