-- Q15: Cohort retention.
-- Cohort means: group customers by the month they registered.
-- Retention means: what percent of that group ordered again in month 0, 1, 2, 3.

WITH users AS (
  SELECT
    customer_id,
    substr(registration_date, 1, 7) AS reg_month,

    -- Example: July 2026 becomes 2026 * 12 + 7.
    -- This makes month difference simple subtraction.
    CAST(substr(registration_date, 1, 4) AS INT) * 12
      + CAST(substr(registration_date, 6, 2) AS INT) AS reg_month_num
  FROM customers
),

orders_used AS (
  SELECT DISTINCT
    u.reg_month,
    u.customer_id,

    -- 0 = same month as registration
    -- 1 = next month
    -- 2 = two months later
    CAST(substr(o.order_date, 1, 4) AS INT) * 12
      + CAST(substr(o.order_date, 6, 2) AS INT)
      - u.reg_month_num AS month_no
  FROM users u
  JOIN orders o ON o.customer_id = u.customer_id
  WHERE o.status <> 'CANCELLED'
),

counts AS (
  SELECT
    reg_month,
    month_no,
    COUNT(DISTINCT customer_id) AS active_users
  FROM orders_used
  WHERE month_no BETWEEN 0 AND 3
  GROUP BY reg_month, month_no
),

group_size AS (
  SELECT
    reg_month,
    COUNT(*) AS total_users
  FROM users
  GROUP BY reg_month
)

SELECT
  g.reg_month,
  g.total_users,

  ROUND(100.0 * COALESCE(SUM(CASE WHEN c.month_no = 0 THEN c.active_users END), 0) / g.total_users, 2) AS month_0_pct,
  ROUND(100.0 * COALESCE(SUM(CASE WHEN c.month_no = 1 THEN c.active_users END), 0) / g.total_users, 2) AS month_1_pct,
  ROUND(100.0 * COALESCE(SUM(CASE WHEN c.month_no = 2 THEN c.active_users END), 0) / g.total_users, 2) AS month_2_pct,
  ROUND(100.0 * COALESCE(SUM(CASE WHEN c.month_no = 3 THEN c.active_users END), 0) / g.total_users, 2) AS month_3_pct

FROM group_size g
LEFT JOIN counts c ON c.reg_month = g.reg_month
GROUP BY g.reg_month, g.total_users
ORDER BY g.reg_month;
