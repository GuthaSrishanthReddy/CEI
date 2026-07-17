-- Q1: Total net revenue by category.
SELECT category, ROUND(SUM(net_revenue), 2) AS net_revenue
FROM v_revenue
GROUP BY category
ORDER BY net_revenue DESC;

-- Q2: Top 10 customers by net revenue.
SELECT customer_id, ROUND(SUM(net_revenue), 2) AS net_revenue
FROM v_revenue
WHERE customer_id IS NOT NULL
GROUP BY customer_id
ORDER BY net_revenue DESC, customer_id
LIMIT 10;

-- Q3: Monthly revenue for the last 12 data months.
WITH monthly AS (
  SELECT order_month AS ym, SUM(net_revenue) AS revenue
  FROM v_revenue
  GROUP BY order_month
)
SELECT ym, ROUND(revenue, 2) AS net_revenue
FROM monthly
ORDER BY ym DESC
LIMIT 12;

-- Q4: Customers with orders but zero delivered orders.
SELECT c.customer_id, c.customer_name, COUNT(o.order_id) AS order_count
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.customer_name
HAVING NOT EXISTS (
  SELECT 1 FROM orders od
  WHERE od.customer_id = c.customer_id AND od.status = 'DELIVERED'
)
ORDER BY order_count DESC, c.customer_id;

-- Q5: Products where returned units exceed purchased units.
SELECT product_id, product_name, category,
       SUM(CASE WHEN quantity < 0 THEN ABS(quantity) ELSE 0 END) AS returned_units,
       SUM(CASE WHEN quantity > 0 THEN quantity ELSE 0 END) AS purchased_units
FROM v_revenue
GROUP BY product_id, product_name, category
HAVING returned_units > purchased_units
ORDER BY returned_units DESC, product_id;

-- Q6: Unit-based return rate by category.
SELECT category,
       ROUND(1.0 * SUM(CASE WHEN quantity < 0 THEN ABS(quantity) ELSE 0 END) /
             NULLIF(SUM(ABS(quantity)), 0), 4) AS return_rate
FROM v_revenue
GROUP BY category
ORDER BY return_rate DESC;
