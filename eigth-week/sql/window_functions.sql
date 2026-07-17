-- Q7: Running daily revenue by region.
WITH daily AS (
  SELECT region_code, order_day, SUM(net_revenue) AS daily_revenue
  FROM v_revenue
  GROUP BY region_code, order_day
)
SELECT region_code, order_day, ROUND(daily_revenue, 2) AS daily_revenue,
       ROUND(SUM(daily_revenue) OVER (
         PARTITION BY region_code ORDER BY order_day ROWS UNBOUNDED PRECEDING
       ), 2) AS running_revenue
FROM daily
ORDER BY region_code, order_day;

-- Q8: Product rank within category by revenue.
WITH product_revenue AS (
  SELECT category, product_id, product_name, SUM(net_revenue) AS total_revenue
  FROM v_revenue
  GROUP BY category, product_id, product_name
)
SELECT category, product_id, product_name, ROUND(total_revenue, 2) AS total_revenue,
       DENSE_RANK() OVER (PARTITION BY category ORDER BY total_revenue DESC, product_id) AS revenue_rank
FROM product_revenue
ORDER BY category, revenue_rank, product_id;

-- Q9: Days between customer orders and at-risk flag.
WITH order_grain AS (
  SELECT DISTINCT order_id, customer_id, order_date
  FROM orders
  WHERE customer_id IS NOT NULL
),
gaps AS (
  SELECT customer_id, order_id, order_date,
         julianday(order_date) - julianday(LAG(order_date) OVER (
           PARTITION BY customer_id ORDER BY order_date, order_id
         )) AS days_since_previous
  FROM order_grain
),
scored AS (
  SELECT *,
         AVG(days_since_previous) OVER (PARTITION BY customer_id) AS avg_gap,
         COUNT(days_since_previous) OVER (PARTITION BY customer_id) AS gap_count
  FROM gaps
)
SELECT customer_id, order_id, order_date, ROUND(days_since_previous, 2) AS days_since_previous,
       CASE
         WHEN gap_count = 0 THEN 'Insufficient Data'
         WHEN avg_gap > 30 THEN 'At Risk'
         ELSE 'Active'
       END AS risk_status
FROM scored
ORDER BY customer_id, order_date, order_id;

-- Q10: Monthly customer revenue buckets.
WITH monthly_customer AS (
  SELECT order_month, customer_id, SUM(net_revenue) AS monthly_revenue
  FROM v_revenue
  WHERE customer_id IS NOT NULL
  GROUP BY order_month, customer_id
),
bucketed AS (
  SELECT order_month,
         CASE
           WHEN monthly_revenue > 10000 THEN 'High'
           WHEN monthly_revenue >= 5000 THEN 'Medium'
           ELSE 'Low'
         END AS revenue_bucket
  FROM monthly_customer
)
SELECT order_month, revenue_bucket, COUNT(*) AS customer_count
FROM bucketed
GROUP BY order_month, revenue_bucket
ORDER BY order_month,
  CASE revenue_bucket WHEN 'High' THEN 1 WHEN 'Medium' THEN 2 ELSE 3 END;

-- Q11: Customer lifetime value quartiles.
WITH ltv AS (
  SELECT customer_id, SUM(net_revenue) AS total_value
  FROM v_revenue
  WHERE customer_id IS NOT NULL
  GROUP BY customer_id
),
ranked AS (
  SELECT *, NTILE(4) OVER (ORDER BY total_value DESC, customer_id) AS quartile
  FROM ltv
)
SELECT customer_id, ROUND(total_value, 2) AS total_value,
       CASE quartile WHEN 1 THEN 'Platinum' WHEN 2 THEN 'Gold' WHEN 3 THEN 'Silver' ELSE 'Bronze' END AS ltv_segment
FROM ranked
ORDER BY total_value DESC, customer_id;

-- Q12: Year-over-year monthly revenue growth.
WITH monthly AS (
  SELECT order_month AS ym, SUM(net_revenue) AS revenue
  FROM v_revenue
  GROUP BY order_month
),
lagged AS (
  SELECT ym, revenue, LAG(revenue, 12) OVER (ORDER BY ym) AS prev_year_revenue
  FROM monthly
)
SELECT ym, ROUND(revenue, 2) AS revenue, ROUND(prev_year_revenue, 2) AS prev_year_revenue,
       ROUND((revenue - prev_year_revenue) * 100.0 / NULLIF(prev_year_revenue, 0), 2) AS yoy_growth_pct
FROM lagged
ORDER BY ym;

-- Q13: Customers whose first and last purchased categories differ.
WITH ordered AS (
  SELECT customer_id, category, order_date, item_id,
         FIRST_VALUE(category) OVER (
           PARTITION BY customer_id ORDER BY order_date, item_id
           ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
         ) AS first_category,
         LAST_VALUE(category) OVER (
           PARTITION BY customer_id ORDER BY order_date, item_id
           ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
         ) AS last_category
  FROM v_revenue
  WHERE customer_id IS NOT NULL AND quantity > 0
)
SELECT DISTINCT customer_id, first_category, last_category,
       CASE WHEN first_category <> last_category THEN 'Yes' ELSE 'No' END AS category_shift
FROM ordered
ORDER BY category_shift DESC, customer_id;

-- Q14: Pareto revenue contribution by customer.
WITH customer_revenue AS (
  SELECT customer_id, SUM(net_revenue) AS revenue
  FROM v_revenue
  WHERE customer_id IS NOT NULL
  GROUP BY customer_id
  HAVING revenue > 0
)
SELECT customer_id, ROUND(revenue, 2) AS revenue,
       ROUND(100.0 * ROW_NUMBER() OVER (ORDER BY revenue DESC, customer_id) / COUNT(*) OVER (), 2) AS customer_percentile,
       ROUND(100.0 * SUM(revenue) OVER (
         ORDER BY revenue DESC, customer_id ROWS UNBOUNDED PRECEDING
       ) / SUM(revenue) OVER (), 2) AS cumulative_revenue_pct
FROM customer_revenue
ORDER BY revenue DESC, customer_id;

-- Q16: Frequently bought together product pairs.
WITH pairs AS (
  SELECT a.product_id AS product_a, b.product_id AS product_b, COUNT(DISTINCT a.order_id) AS times_bought_together
  FROM v_revenue a
  JOIN v_revenue b ON a.order_id = b.order_id AND a.product_id < b.product_id
  WHERE a.quantity > 0 AND b.quantity > 0
  GROUP BY a.product_id, b.product_id
)
SELECT product_a, product_b, times_bought_together,
       DENSE_RANK() OVER (ORDER BY times_bought_together DESC, product_a, product_b) AS pair_rank
FROM pairs
WHERE times_bought_together >= 3
ORDER BY times_bought_together DESC, product_a, product_b;
