-- Delivered orders overview: identify the analysis period and total order volume
SELECT 
	MIN(order_purchase_timestamp) AS earliest_order,
	MAX(order_purchase_timestamp) AS latest_order,
	COUNT(*) AS total_orders
FROM orders 
WHERE order_status = 'delivered';

-- Monthly sales performance: calculate GMV, order volume and average order value
CREATE OR REPLACE VIEW public.vw_monthly_revenue AS
SELECT 
	DATE_TRUNC('month', order_purchase_timestamp) AS month,
	COUNT(DISTINCT ot.order_id) AS monthly_orders,
	SUM(ot.price) AS monthly_gmv,
	ROUND(SUM(ot.price) / COUNT(DISTINCT ot.order_id), 2) AS monthly_aov
FROM order_items ot
INNER JOIN orders o
	ON ot.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY month;


-- Monthly sales trend analysis: calculate MoM growth and 3-month rolling average using a continuous monthly calendar
CREATE OR REPLACE VIEW public.vw_monthly_trends AS
WITH monthly_metrics AS (
	SELECT 
		DATE_TRUNC('month', order_purchase_timestamp) AS month,
		COUNT(DISTINCT ot.order_id) AS monthly_orders,
		SUM(ot.price) AS monthly_gmv,
		ROUND(SUM(ot.price) / COUNT(DISTINCT ot.order_id), 2) AS monthly_aov
	FROM order_items ot
	INNER JOIN orders o
		ON ot.order_id = o.order_id
	WHERE o.order_status = 'delivered'
	GROUP BY month
),
monthly_calendar AS (
	SELECT generate_series(DATE '2016-09-01', DATE '2018-08-01', INTERVAL '1 month') AS calendar
),
monthly_comparison AS (
	SELECT *
	FROM monthly_calendar mc
	LEFT JOIN monthly_metrics mm
		ON mc.calendar = mm.month
)
SELECT 
	calendar,
	ROUND((monthly_gmv - LAG(monthly_gmv) OVER (ORDER BY calendar)) * 100.0 / LAG(monthly_gmv) OVER (ORDER BY calendar), 2) AS Month_over_Month_Growth,
	CASE WHEN COUNT(monthly_gmv) OVER (ORDER BY calendar ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) = 3 THEN ROUND(AVG(monthly_gmv) OVER (ORDER BY calendar ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) ELSE NULL END AS three_month_rolling_average
FROM monthly_comparison
ORDER BY calendar;


-- Monthly seasonality analysis: calculate average GMV by calendar month across available years
CREATE OR REPLACE VIEW public.vw_monthly_seasonality AS
WITH monthly_metrics AS (
	SELECT 
		DATE_TRUNC('month', order_purchase_timestamp) AS month,
		COUNT(DISTINCT ot.order_id) AS monthly_orders,
		SUM(ot.price) AS monthly_gmv,
		ROUND(SUM(ot.price) / COUNT(DISTINCT ot.order_id), 2) AS monthly_aov
	FROM order_items ot
	INNER JOIN orders o
		ON ot.order_id = o.order_id
	WHERE o.order_status = 'delivered'
	GROUP BY month
)
SELECT
	EXTRACT(MONTH FROM month) AS month_number,
	ROUND(AVG(monthly_gmv), 2) AS avg_monthly_gmv
FROM monthly_metrics
GROUP BY EXTRACT(MONTH FROM month)
ORDER BY month_number

