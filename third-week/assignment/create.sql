-- Create customers table

CREATE TABLE customers AS
SELECT `Customer ID` AS Customer_ID,
`Customer Name` AS Customer_Name,
Segment,
Region,
State,
City
FROM (
SELECT
`Customer ID`,
`Customer Name`,
Segment,
Region,
State,
City,
COUNT(*) AS frequency,
ROW_NUMBER() OVER (
PARTITION BY `Customer ID`
ORDER BY COUNT(*) DESC
) AS rn
FROM superstore
GROUP BY
`Customer ID`,
`Customer Name`,
Segment,
Region,
State,
City
) tempData
WHERE rn = 1;


-- Create products table

CREATE TABLE products AS
SELECT DISTINCT
`Product ID` AS Product_ID,
`Product Name` AS Product_Name,
Category,
`Sub-Category` AS Sub_Category
FROM superstore;


-- Create orders table

CREATE TABLE orders AS
SELECT
`Row ID` AS Row_ID,
`Order ID` AS Order_ID,
`Order Date` AS Order_Date,
`Ship Date` AS Ship_Date,
`Ship Mode` AS Ship_Mode,
`Customer ID` AS Customer_ID,
`Product ID` AS Product_ID,
Sales,
Quantity,
Discount,
Profit
FROM superstore;
