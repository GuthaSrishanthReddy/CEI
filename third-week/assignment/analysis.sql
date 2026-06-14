-- Orders above average sales

SELECT Order_ID, Customer_ID, Product_ID, Sales
FROM orders WHERE Sales > (
SELECT AVG(Sales)
FROM orders
)
ORDER BY Sales DESC LIMIT 10;


-- Highest order for each customer

WITH maxSales AS (
SELECT Customer_ID,
MAX(Sales) AS maxSale
FROM orders
GROUP BY Customer_ID
)
SELECT o.Customer_ID, o.Order_ID, o.Sales
FROM orders o
JOIN maxSales m
ON o.Customer_ID = m.Customer_ID
AND o.Sales = m.maxSale
ORDER BY o.Sales DESC
LIMIT 10;


-- Total sales per customer using CTE

WITH sales AS (
SELECT c.Customer_ID, c.Customer_Name,
SUM(o.Sales) AS TotalSales, SUM(o.Profit) AS TotalProfit,
COUNT(DISTINCT o.Order_ID) AS OrderCount
FROM customers c JOIN orders o
ON c.Customer_ID = o.Customer_ID
GROUP BY c.Customer_ID, c.Customer_Name
)

SELECT *
FROM sales
ORDER BY TotalSales DESC
LIMIT 10;


-- ROW_NUMBER and RANK

WITH sales AS (
SELECT c.Customer_ID, c.Customer_Name,
SUM(o.Sales) AS TotalSales,
SUM(o.Profit) AS TotalProfit
FROM customers c
JOIN orders o
ON c.Customer_ID = o.Customer_ID
GROUP BY c.Customer_ID, c.Customer_Name
)

SELECT Customer_ID, Customer_Name,
ROUND(TotalSales, 2) AS TotalSales,
ROUND(TotalProfit, 2) AS TotalProfit,

ROW_NUMBER() OVER (
ORDER BY TotalSales DESC
) AS rowNo,
RANK() OVER (
ORDER BY TotalSales DESC
) AS rankNo FROM sales
ORDER BY TotalSales DESC;


-- Top 10 customers

WITH sales AS (
SELECT c.Customer_ID, c.Customer_Name, c.Region,
SUM(o.Sales) AS TotalSales
FROM customers c
JOIN orders o
ON c.Customer_ID = o.Customer_ID
GROUP BY c.Customer_ID, c.Customer_Name, c.Region
), topData AS (
SELECT *, RANK() OVER (
ORDER BY TotalSales DESC
) AS rankNo
FROM sales
)

SELECT Customer_ID, Customer_Name, Region,
ROUND(TotalSales, 2) AS TotalSales, rankNo
FROM topData
WHERE rankNo <= 10
ORDER BY rankNo;


-- Lowest customers by sales

WITH sales AS (
SELECT c.Customer_ID, c.Customer_Name,
SUM(o.Sales) AS TotalSales
FROM customers c
JOIN orders o
ON c.Customer_ID = o.Customer_ID
GROUP BY c.Customer_ID, c.Customer_Name
),

lowData AS (
SELECT *, RANK() OVER (
ORDER BY TotalSales ASC
) AS lowRank
FROM sales
)

SELECT Customer_ID, Customer_Name,
ROUND(TotalSales, 2) AS TotalSales, lowRank
FROM lowData
WHERE lowRank <= 10
ORDER BY lowRank;


-- Customers with single order

WITH orderData AS (
SELECT c.Customer_ID, c.Customer_Name,
COUNT(DISTINCT o.Order_ID) AS OrderCount,
SUM(o.Sales) AS TotalSales
FROM customers c 
JOIN orders o
ON c.Customer_ID = o.Customer_ID
GROUP BY c.Customer_ID, c.Customer_Name
)

SELECT Customer_ID, Customer_Name, OrderCount,
ROUND(TotalSales, 2) AS TotalSales FROM orderData
WHERE OrderCount = 1
ORDER BY TotalSales DESC;


-- Customers above average customer sales

WITH sales AS (
SELECT c.Customer_ID, c.Customer_Name,
SUM(o.Sales) AS TotalSales
FROM customers c
JOIN orders o ON c.Customer_ID = o.Customer_ID
GROUP BY c.Customer_ID, c.Customer_Name
)

SELECT Customer_ID, Customer_Name,
ROUND(TotalSales, 2) AS TotalSales
FROM sales
WHERE TotalSales > (
SELECT AVG(TotalSales) FROM sales
) ORDER BY TotalSales DESC;


-- Final combined result

WITH sales AS (
SELECT c.Customer_ID, c.Customer_Name, c.Segment, c.Region,
SUM(o.Sales) AS TotalSales, SUM(o.Profit) AS TotalProfit
FROM customers c
JOIN orders o ON c.Customer_ID = o.Customer_ID
GROUP BY c.Customer_ID, c.Customer_Name, c.Segment, c.Region
)

SELECT Customer_ID, Customer_Name, Segment, Region,
ROUND(TotalSales, 2) AS TotalSales, ROUND(TotalProfit, 2) AS TotalProfit,
RANK() OVER (
ORDER BY TotalSales DESC
) AS OverallRank
FROM sales
ORDER BY OverallRank
LIMIT 20;