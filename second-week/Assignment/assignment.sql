-- Explore data
DESCRIBE `superstore`;
SELECT *
FROM `superstore`
LIMIT 10;

-- Validate Dataset
SELECT COUNT(*) AS total_rows
FROM `superstore`;

SELECT COUNT(DISTINCT `Customer ID`) AS unique_customers
FROM `superstore`;

SELECT
    SUM(CASE WHEN Sales IS NULL THEN 1 ELSE 0 END) AS null_sales,
    SUM(CASE WHEN Profit IS NULL THEN 1 ELSE 0 END) AS null_profit
FROM `superstore`;

-- WHERE Filters-- Explore data
DESCRIBE `superstore`;

SELECT *
FROM `superstore`
LIMIT 10;

-- Validate Dataset
SELECT COUNT(*) AS total_rows
FROM `superstore`;

SELECT COUNT(DISTINCT `Customer ID`) AS customers
FROM `superstore`;

SELECT
    SUM(CASE WHEN Sales IS NULL THEN 1 ELSE 0 END) AS missing_sales,
    SUM(CASE WHEN Profit IS NULL THEN 1 ELSE 0 END) AS missing_profit
FROM `superstore`;

-- WHERE Filters

SELECT
    Region,
    COUNT(*) AS orders,
    ROUND(SUM(Sales), 2) AS revenue
FROM `superstore`
WHERE Region = 'West'
GROUP BY Region;

SELECT
    `Product Name`,
    ROUND(Sales, 2) AS sales,
    Discount,
    ROUND(Profit, 2) AS profit
FROM `superstore`
WHERE Category = 'Technology'
    AND Sales > 1000
ORDER BY Sales DESC
LIMIT 10;

SELECT
    `Product Name`,
    ROUND(Sales, 2) AS sales,
    Discount,
    ROUND(Profit, 2) AS profit
FROM `superstore`
WHERE Discount >= 0.40
ORDER BY Profit;

-- GROUP BY Aggregations

SELECT
    Region,
    COUNT(*) AS orders,
    ROUND(SUM(Sales), 2) AS revenue,
    ROUND(SUM(Profit), 2) AS profit,
    ROUND(AVG(Sales), 2) AS avg_order_value
FROM `superstore`
GROUP BY Region
ORDER BY revenue DESC;

SELECT
    Category,
    ROUND(SUM(Sales), 2) AS revenue,
    SUM(Quantity) AS quantity_sold,
    ROUND(AVG(Profit), 2) AS avg_profit
FROM `superstore`
GROUP BY Category
ORDER BY revenue DESC;

SELECT
    Segment,
    ROUND(SUM(Sales), 2) AS revenue,
    ROUND(SUM(Profit), 2) AS profit
FROM `superstore`
GROUP BY Segment
ORDER BY revenue DESC;

-- Sorting & Limiting

SELECT
    `Product Name`,
    ROUND(SUM(Sales), 2) AS revenue,
    SUM(Quantity) AS quantity
FROM `superstore`
GROUP BY `Product Name`
ORDER BY revenue DESC
LIMIT 10;

SELECT
    `Customer Name`,
    COUNT(DISTINCT `Order ID`) AS orders,
    ROUND(SUM(Sales), 2) AS revenue,
    ROUND(SUM(Profit), 2) AS profit
FROM `superstore`
GROUP BY `Customer Name`
ORDER BY revenue DESC
LIMIT 10;

SELECT
    `Product Name`,
    ROUND(SUM(Profit), 2) AS total_loss
FROM `superstore`
GROUP BY `Product Name`
ORDER BY total_loss
LIMIT 10;

-- Business Use Cases

SELECT
    YEAR(STR_TO_DATE(`Order Date`, '%m/%d/%Y')) AS year,
    ROUND(SUM(Sales), 2) AS revenue,
    ROUND(SUM(Profit), 2) AS profit,
    COUNT(DISTINCT `Order ID`) AS orders
FROM `superstore`
GROUP BY year
ORDER BY year;

SELECT 
    YEAR(STR_TO_DATE(`Order Date`, '%m/%d/%Y')) AS year,
    MONTH(STR_TO_DATE(`Order Date`, '%m/%d/%Y')) AS month,
    ROUND(SUM(Sales), 2) AS monthly_sales
FROM
    `superstore`
GROUP BY year , month
ORDER BY year , month;

SELECT
    Category,
    `Sub-Category`,
    COUNT(*) AS loss_rows,
    ROUND(SUM(Profit), 2) AS total_loss
FROM `superstore`
WHERE Profit < 0
GROUP BY Category, `Sub-Category`
ORDER BY total_loss;

SELECT
    `Order ID`,
    COUNT(*) AS duplicate_count
FROM `superstore`
GROUP BY `Order ID`
HAVING COUNT(*) > 1;