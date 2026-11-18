-- Customer purchase history: initial exploration
CREATE OR REPLACE VIEW public.vw_customer_overview AS
WITH customer_orders AS (
	SELECT
		c.customer_unique_id,
		COUNT(*) AS orders_number
	FROM orders o
	LEFT JOIN customers c
		ON o.customer_id = c.customer_id
	GROUP BY c.customer_unique_id
	HAVING COUNT(o.order_id) > 1
)
SELECT 
	COUNT(DISTINCT o.order_id) AS total_orders,
	COUNT(DISTINCT c.customer_unique_id) AS unique_customers,
	COUNT(DISTINCT co.customer_unique_id)  AS customers_more_than_1_order
FROM orders o
LEFT JOIN customers c
	ON o.customer_id = c.customer_id
LEFT join customer_orders co
	ON c.customer_unique_id = co.customer_unique_id;

-- Customer cohort assignment: first purchase date and cohort month
SELECT 
	c.customer_unique_id,
	MIN(o.order_purchase_timestamp) AS first_order_date,
	DATE_TRUNC('month', MIN(o.order_purchase_timestamp)) AS cohort_month
	FROM orders o
LEFT JOIN customers c
	ON o.customer_id = c.customer_id
GROUP BY customer_unique_id;

-- Customer cohort size: number of customers per cohort
WITH cohort_assignment AS (
	SELECT 
		c.customer_unique_id,
		MIN(o.order_purchase_timestamp) AS first_order_date,
		DATE_TRUNC('month', MIN(o.order_purchase_timestamp)) AS cohort_month
		FROM orders o
	LEFT JOIN customers c
		ON o.customer_id = c.customer_id
	GROUP BY customer_unique_id
)
SELECT 
	cohort_month,
	COUNT(*) AS cohort_size
FROM cohort_assignment
GROUP BY cohort_month
ORDER BY cohort_size DESC;
	
-- Customer activity: monthly purchase history
SELECT DISTINCT
	c.customer_unique_id,
	DATE_TRUNC('month', o.order_purchase_timestamp) AS activity_month
FROM orders o
LEFT JOIN customers c
	ON o.customer_id = c.customer_id;

-- Customer cohort activity: match each customer with their cohort month
WITH cohort_assignment AS (
	SELECT 
		c.customer_unique_id,
		MIN(o.order_purchase_timestamp) AS first_order_date,
		DATE_TRUNC('month', MIN(o.order_purchase_timestamp)) AS cohort_month
		FROM orders o
	LEFT JOIN customers c
		ON o.customer_id = c.customer_id
	GROUP BY customer_unique_id
),
customer_activity AS (
	SELECT DISTINCT
		c.customer_unique_id,
		DATE_TRUNC('month', o.order_purchase_timestamp) AS activity_month
	FROM orders o
	LEFT JOIN customers c
		ON o.customer_id = c.customer_id
)
SELECT 
	ca.customer_unique_id,
	ca.activity_month,
	cas.cohort_month AS cohort_month
	FROM customer_activity ca
INNER JOIN cohort_assignment cas
	ON ca.customer_unique_id = cas.customer_unique_id;


-- Cohort age: calculate months since the first purchase
WITH cohort_assignment AS (
	SELECT 
		c.customer_unique_id,
		MIN(o.order_purchase_timestamp) AS first_order_date,
		DATE_TRUNC('month', MIN(o.order_purchase_timestamp)) AS cohort_month
		FROM orders o
	LEFT JOIN customers c
		ON o.customer_id = c.customer_id
	GROUP BY customer_unique_id
),
customer_activity AS (
	SELECT DISTINCT
		c.customer_unique_id,
		DATE_TRUNC('month', o.order_purchase_timestamp) AS activity_month
	FROM orders o
	LEFT JOIN customers c
		ON o.customer_id = c.customer_id
),
cohort_activity AS (
	SELECT 
		ca.customer_unique_id,
		ca.activity_month,
		cas.cohort_month AS cohort_month
	FROM customer_activity ca
	INNER JOIN cohort_assignment cas
		ON ca.customer_unique_id = cas.customer_unique_id
),
difference AS (
	SELECT
		customer_unique_id,
		(EXTRACT(YEAR FROM activity_month) - EXTRACT(YEAR FROM cohort_month)) * 12 AS year_difference,
		EXTRACT(MONTH FROM activity_month) - EXTRACT(MONTH FROM cohort_month) AS month_difference
	FROM cohort_activity 
)
SELECT 
	customer_unique_id,
	year_difference + month_difference AS months_since_cohort
FROM difference ;

-- Monthly cohort retention: count active customers by cohort and month
WITH cohort_assignment AS (
	SELECT 
		c.customer_unique_id,
		MIN(o.order_purchase_timestamp) AS first_order_date,
		DATE_TRUNC('month', MIN(o.order_purchase_timestamp)) AS cohort_month
		FROM orders o
	LEFT JOIN customers c
		ON o.customer_id = c.customer_id
	GROUP BY customer_unique_id
),
customer_activity AS (
	SELECT DISTINCT
		c.customer_unique_id,
		DATE_TRUNC('month', o.order_purchase_timestamp) AS activity_month
	FROM orders o
	LEFT JOIN customers c
		ON o.customer_id = c.customer_id
),
cohort_activity AS (
	SELECT 
		ca.customer_unique_id,
		ca.activity_month,
		cas.cohort_month AS cohort_month
	FROM customer_activity ca
	INNER JOIN cohort_assignment cas
		ON ca.customer_unique_id = cas.customer_unique_id
),
difference AS (
	SELECT
		customer_unique_id,
		cohort_month,
		(EXTRACT(YEAR FROM activity_month) - EXTRACT(YEAR FROM cohort_month)) * 12 AS year_difference,
		EXTRACT(MONTH FROM activity_month) - EXTRACT(MONTH FROM cohort_month) AS month_difference
	FROM cohort_activity 
)
SELECT  
	cohort_month,
	year_difference + month_difference AS months_since_cohort,
	COUNT(DISTINCT customer_unique_id) AS active_customers
FROM difference
GROUP BY cohort_month, year_difference + month_difference;


-- Monthly cohort retention: calculate active customers and retention rate by cohort
WITH cohort_assignment AS (
	SELECT 
		c.customer_unique_id,
		MIN(o.order_purchase_timestamp) AS first_order_date,
		DATE_TRUNC('month', MIN(o.order_purchase_timestamp)) AS cohort_month
		FROM orders o
	LEFT JOIN customers c
		ON o.customer_id = c.customer_id
	GROUP BY customer_unique_id
),
customer_activity AS (
	SELECT DISTINCT
		c.customer_unique_id,
		DATE_TRUNC('month', o.order_purchase_timestamp) AS activity_month
	FROM orders o
	LEFT JOIN customers c
		ON o.customer_id = c.customer_id
),
cohort_activity AS (
	SELECT 
		ca.customer_unique_id,
		ca.activity_month,
		cas.cohort_month AS cohort_month
	FROM customer_activity ca
	INNER JOIN cohort_assignment cas
		ON ca.customer_unique_id = cas.customer_unique_id
),
difference AS (
	SELECT
		customer_unique_id,
		cohort_month,
		(EXTRACT(YEAR FROM activity_month) - EXTRACT(YEAR FROM cohort_month)) * 12 AS year_difference,
		EXTRACT(MONTH FROM activity_month) - EXTRACT(MONTH FROM cohort_month) AS month_difference
	FROM cohort_activity 
),
monthly_activity AS (
	SELECT  
		cohort_month,
		year_difference + month_difference AS months_since_cohort,
		COUNT(DISTINCT customer_unique_id) AS active_customers
	FROM difference
	GROUP BY cohort_month, year_difference + month_difference
),
cohort_size AS (
    SELECT
        cohort_month,
        COUNT(DISTINCT customer_unique_id) AS cohort_size
    FROM cohort_assignment
    GROUP BY cohort_month
)
SELECT 
	ma.cohort_month,
	ma.months_since_cohort,
	cohort_size,
	active_customers,
	ROUND(active_customers * 100.0 / cohort_size, 2) AS retention_rate
FROM monthly_activity ma
INNER JOIN cohort_size cs
	ON ma.cohort_month = cs.cohort_month;

-- Check the date range of customer orders
SELECT 
	MIN(order_purchase_timestamp), 
	MAX(order_purchase_timestamp)
FROM orders;

-- Calculate the maximum observation period for each customer cohort
WITH cohort_assignment AS (
	SELECT 
		c.customer_unique_id,
		MIN(o.order_purchase_timestamp) AS first_order_date,
		DATE_TRUNC('month', MIN(o.order_purchase_timestamp)) AS cohort_month
		FROM orders o
	LEFT JOIN customers c
		ON o.customer_id = c.customer_id
	GROUP BY customer_unique_id
)
SELECT
	cohort_month,
	((EXTRACT(YEAR FROM DATE '2018-10-01') - EXTRACT(YEAR FROM cohort_month)) * 12) + (EXTRACT(MONTH FROM DATE '2018-10-01') - EXTRACT(MONTH FROM cohort_month)) AS max_month_number
FROM cohort_assignment
GROUP BY cohort_month
ORDER BY cohort_month;


-- Check monthly order distribution and customer activity
SELECT
    DATE_TRUNC('month', order_purchase_timestamp) AS purchase_month,
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT customer_id) AS unique_customers
FROM orders
GROUP BY purchase_month
ORDER BY purchase_month;

-- Final cohort retention rate: calculate monthly customer retention
CREATE OR REPLACE VIEW public.vw_customer_cohort_retention AS
WITH cohort_assignment AS (
	SELECT 
		c.customer_unique_id,
		MIN(o.order_purchase_timestamp) AS first_order_date,
		DATE_TRUNC('month', MIN(o.order_purchase_timestamp)) AS cohort_month
		FROM orders o
	LEFT JOIN customers c
		ON o.customer_id = c.customer_id
	GROUP BY customer_unique_id
),
cohort_months AS (
	SELECT
		cohort_month,
		((EXTRACT(YEAR FROM DATE '2018-10-01') - EXTRACT(YEAR FROM cohort_month)) * 12) + (EXTRACT(MONTH FROM DATE '2018-10-01') - EXTRACT(MONTH FROM cohort_month)) AS max_month_number
	FROM cohort_assignment
	GROUP BY cohort_month
),
customer_activity AS (
	SELECT DISTINCT
		c.customer_unique_id,
		DATE_TRUNC('month', o.order_purchase_timestamp) AS activity_month
	FROM orders o
	LEFT JOIN customers c
		ON o.customer_id = c.customer_id
),
cohort_activity AS (
	SELECT 
		ca.customer_unique_id,
		ca.activity_month,
		cas.cohort_month AS cohort_month
	FROM customer_activity ca
	INNER JOIN cohort_assignment cas
		ON ca.customer_unique_id = cas.customer_unique_id
),
difference AS (
	SELECT
		customer_unique_id,
		cohort_month,
		(EXTRACT(YEAR FROM activity_month) - EXTRACT(YEAR FROM cohort_month)) * 12 AS year_difference,
		EXTRACT(MONTH FROM activity_month) - EXTRACT(MONTH FROM cohort_month) AS month_difference
	FROM cohort_activity 
),
monthly_activity AS (
	SELECT  
		cohort_month,
		year_difference + month_difference AS months_since_cohort,
		COUNT(DISTINCT customer_unique_id) AS active_customers
	FROM difference
	GROUP BY cohort_month, year_difference + month_difference
),
cohort_size AS (
    SELECT
        cohort_month,
        COUNT(DISTINCT customer_unique_id) AS cohort_size
    FROM cohort_assignment
    GROUP BY cohort_month
)
SELECT 
	cm.cohort_month,
	months.month_number AS months_since_cohort,
	cs.cohort_size,
	COALESCE(ma.active_customers, 0) AS active_customers,
	ROUND(COALESCE(ma.active_customers, 0) * 100.0 / cs.cohort_size, 2) AS retention_rate
FROM cohort_months cm
CROSS JOIN generate_series (0, cm.max_month_number) AS months(month_number)
LEFT JOIN monthly_activity ma
	ON cm.cohort_month = ma.cohort_month AND ma.months_since_cohort = months.month_number
INNER JOIN cohort_size cs
	ON cm.cohort_month = cs.cohort_month
ORDER BY cm.cohort_month, months.month_number;


--Customer retention comparison: analyze retention rates in Months 1, 3 and 6
WITH cohort_assignment AS (
	SELECT 
		c.customer_unique_id,
		MIN(o.order_purchase_timestamp) AS first_order_date,
		DATE_TRUNC('month', MIN(o.order_purchase_timestamp)) AS cohort_month
		FROM orders o
	LEFT JOIN customers c
		ON o.customer_id = c.customer_id
	GROUP BY customer_unique_id
),
cohort_months AS (
	SELECT
		cohort_month,
		((EXTRACT(YEAR FROM DATE '2018-10-01') - EXTRACT(YEAR FROM cohort_month)) * 12) + (EXTRACT(MONTH FROM DATE '2018-10-01') - EXTRACT(MONTH FROM cohort_month)) AS max_month_number
	FROM cohort_assignment
	GROUP BY cohort_month
),
customer_activity AS (
	SELECT DISTINCT
		c.customer_unique_id,
		DATE_TRUNC('month', o.order_purchase_timestamp) AS activity_month
	FROM orders o
	LEFT JOIN customers c
		ON o.customer_id = c.customer_id
),
cohort_activity AS (
	SELECT 
		ca.customer_unique_id,
		ca.activity_month,
		cas.cohort_month AS cohort_month
	FROM customer_activity ca
	INNER JOIN cohort_assignment cas
		ON ca.customer_unique_id = cas.customer_unique_id
),
difference AS (
	SELECT
		customer_unique_id,
		cohort_month,
		(EXTRACT(YEAR FROM activity_month) - EXTRACT(YEAR FROM cohort_month)) * 12 AS year_difference,
		EXTRACT(MONTH FROM activity_month) - EXTRACT(MONTH FROM cohort_month) AS month_difference
	FROM cohort_activity 
),
monthly_activity AS (
	SELECT  
		cohort_month,
		year_difference + month_difference AS months_since_cohort,
		COUNT(DISTINCT customer_unique_id) AS active_customers
	FROM difference
	GROUP BY cohort_month, year_difference + month_difference
),
cohort_size AS (
    SELECT
        cohort_month,
        COUNT(DISTINCT customer_unique_id) AS cohort_size
    FROM cohort_assignment
    GROUP BY cohort_month
),
cohort_results AS (
	SELECT 
		cm.cohort_month,
		months.month_number AS months_since_cohort,
		cs.cohort_size,
		COALESCE(ma.active_customers, 0) AS active_customers,
		ROUND(COALESCE(ma.active_customers, 0) * 100.0 / cs.cohort_size, 2) AS retention_rate
	FROM cohort_months cm
	CROSS JOIN generate_series (0, cm.max_month_number) AS months(month_number)
	LEFT JOIN monthly_activity ma
		ON cm.cohort_month = ma.cohort_month AND ma.months_since_cohort = months.month_number
	INNER JOIN cohort_size cs
		ON cm.cohort_month = cs.cohort_month
	ORDER BY cm.cohort_month, months.month_number
)
SELECT 
	cohort_month,
	retention_rate
FROM cohort_results
WHERE months_since_cohort = 6
ORDER BY retention_rate DESC;

-- Cohort retention matrix: transform monthly retention rows into columns
WITH cohort_assignment AS (
	SELECT 
		c.customer_unique_id,
		MIN(o.order_purchase_timestamp) AS first_order_date,
		DATE_TRUNC('month', MIN(o.order_purchase_timestamp)) AS cohort_month
		FROM orders o
	LEFT JOIN customers c
		ON o.customer_id = c.customer_id
	GROUP BY customer_unique_id
),
cohort_months AS (
	SELECT
		cohort_month,
		((EXTRACT(YEAR FROM DATE '2018-10-01') - EXTRACT(YEAR FROM cohort_month)) * 12) + (EXTRACT(MONTH FROM DATE '2018-10-01') - EXTRACT(MONTH FROM cohort_month)) AS max_month_number
	FROM cohort_assignment
	GROUP BY cohort_month
),
customer_activity AS (
	SELECT DISTINCT
		c.customer_unique_id,
		DATE_TRUNC('month', o.order_purchase_timestamp) AS activity_month
	FROM orders o
	LEFT JOIN customers c
		ON o.customer_id = c.customer_id
),
cohort_activity AS (
	SELECT 
		ca.customer_unique_id,
		ca.activity_month,
		cas.cohort_month AS cohort_month
	FROM customer_activity ca
	INNER JOIN cohort_assignment cas
		ON ca.customer_unique_id = cas.customer_unique_id
),
difference AS (
	SELECT
		customer_unique_id,
		cohort_month,
		(EXTRACT(YEAR FROM activity_month) - EXTRACT(YEAR FROM cohort_month)) * 12 AS year_difference,
		EXTRACT(MONTH FROM activity_month) - EXTRACT(MONTH FROM cohort_month) AS month_difference
	FROM cohort_activity 
),
monthly_activity AS (
	SELECT  
		cohort_month,
		year_difference + month_difference AS months_since_cohort,
		COUNT(DISTINCT customer_unique_id) AS active_customers
	FROM difference
	GROUP BY cohort_month, year_difference + month_difference
),
cohort_size AS (
    SELECT
        cohort_month,
        COUNT(DISTINCT customer_unique_id) AS cohort_size
    FROM cohort_assignment
    GROUP BY cohort_month
),
cohort_results AS (
	SELECT 
		cm.cohort_month,
		months.month_number AS months_since_cohort,
		cs.cohort_size,
		COALESCE(ma.active_customers, 0) AS active_customers,
		ROUND(COALESCE(ma.active_customers, 0) * 100.0 / cs.cohort_size, 2) AS retention_rate
	FROM cohort_months cm
	CROSS JOIN generate_series (0, cm.max_month_number) AS months(month_number)
	LEFT JOIN monthly_activity ma
		ON cm.cohort_month = ma.cohort_month AND ma.months_since_cohort = months.month_number
	INNER JOIN cohort_size cs
		ON cm.cohort_month = cs.cohort_month
	ORDER BY cm.cohort_month, months.month_number
)

-- Customer cohort retention matrix: pivot monthly retention rates into columns
SELECT
    cohort_month,
    MAX(CASE WHEN months_since_cohort = 0 THEN retention_rate END) AS month_0,
    MAX(CASE WHEN months_since_cohort = 1 THEN retention_rate END) AS month_1,
    MAX(CASE WHEN months_since_cohort = 2 THEN retention_rate END) AS month_2,
    MAX(CASE WHEN months_since_cohort = 3 THEN retention_rate END) AS month_3,
    MAX(CASE WHEN months_since_cohort = 4 THEN retention_rate END) AS month_4,
    MAX(CASE WHEN months_since_cohort = 5 THEN retention_rate END) AS month_5,
    MAX(CASE WHEN months_since_cohort = 6 THEN retention_rate END) AS month_6,
    MAX(CASE WHEN months_since_cohort = 7 THEN retention_rate END) AS month_7,
    MAX(CASE WHEN months_since_cohort = 8 THEN retention_rate END) AS month_8,
    MAX(CASE WHEN months_since_cohort = 9 THEN retention_rate END) AS month_9,
    MAX(CASE WHEN months_since_cohort = 10 THEN retention_rate END) AS month_10,
    MAX(CASE WHEN months_since_cohort = 11 THEN retention_rate END) AS month_11,
    MAX(CASE WHEN months_since_cohort = 12 THEN retention_rate END) AS month_12,
    MAX(CASE WHEN months_since_cohort = 13 THEN retention_rate END) AS month_13,
    MAX(CASE WHEN months_since_cohort = 14 THEN retention_rate END) AS month_14,
    MAX(CASE WHEN months_since_cohort = 15 THEN retention_rate END) AS month_15,
    MAX(CASE WHEN months_since_cohort = 16 THEN retention_rate END) AS month_16,
    MAX(CASE WHEN months_since_cohort = 17 THEN retention_rate END) AS month_17,
    MAX(CASE WHEN months_since_cohort = 18 THEN retention_rate END) AS month_18,
    MAX(CASE WHEN months_since_cohort = 19 THEN retention_rate END) AS month_19,
    MAX(CASE WHEN months_since_cohort = 20 THEN retention_rate END) AS month_20,
    MAX(CASE WHEN months_since_cohort = 21 THEN retention_rate END) AS month_21,
    MAX(CASE WHEN months_since_cohort = 22 THEN retention_rate END) AS month_22,
    MAX(CASE WHEN months_since_cohort = 23 THEN retention_rate END) AS month_23,
    MAX(CASE WHEN months_since_cohort = 24 THEN retention_rate END) AS month_24,
	MAX(CASE WHEN months_since_cohort = 25 THEN retention_rate END) AS month_25
FROM cohort_results
GROUP BY cohort_month
ORDER BY cohort_month;
