-- RFM analysis: define the customer transaction dataset
SELECT 
	MIN(order_purchase_timestamp) AS earliest_order,
	MAX(order_purchase_timestamp) AS latest_order,
	COUNT(*)
FROM orders
WHERE order_status = 'delivered';

-- Customer-level RFM preparation: join delivered orders with customers and order items
SELECT 
	ot.order_id,
	c.customer_unique_id,
	o.order_purchase_timestamp,
	ot.price
FROM order_items ot
LEFT JOIN orders o
	ON ot.order_id = o.order_id
LEFT JOIN customers c
	ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered';


-- Customer-level RFM metrics: calculate recency, frequency and monetary value
SELECT
	c.customer_unique_id,
	DATE '2018-08-30' - MAX(o.order_purchase_timestamp)::DATE AS recency,
	COUNT(DISTINCT ot.order_id) AS frequency,
	SUM(ot.price) AS monetary
FROM order_items ot
LEFT JOIN orders o
	ON ot.order_id = o.order_id
LEFT JOIN customers c
	ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_unique_id;

-- Customer purchase frequency distribution: analyze the number of orders per customer
WITH customer_performance AS (
SELECT
	c.customer_unique_id,
	DATE '2018-08-30' - MAX(o.order_purchase_timestamp)::DATE AS recency,
	COUNT(DISTINCT ot.order_id) AS frequency,
	SUM(ot.price) AS monetary
FROM order_items ot
LEFT JOIN orders o
	ON ot.order_id = o.order_id
LEFT JOIN customers c
	ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_unique_id
)
SELECT 
	frequency,
	COUNT(customer_unique_id) AS total_customers
FROM customer_performance
GROUP BY frequency
ORDER BY frequency;

-- Customer monetary value distribution: analyze spending patterns across customers
WITH customer_performance AS (
SELECT
	c.customer_unique_id,
	DATE '2018-08-30' - MAX(o.order_purchase_timestamp)::DATE AS recency,
	COUNT(DISTINCT ot.order_id) AS frequency,
	SUM(ot.price) AS monetary
FROM order_items ot
LEFT JOIN orders o
	ON ot.order_id = o.order_id
LEFT JOIN customers c
	ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_unique_id
)
SELECT 
	MIN(monetary) AS min_monetary,
	MAX(monetary) AS max_monetary,
	ROUND(AVG(monetary), 2) AS avg_monetary,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY monetary) as median_monetary
FROM customer_performance;

-- Initial RFM scoring: assign quartile-based scores to all three RFM dimensions
WITH customer_performance AS (
SELECT
	c.customer_unique_id,
	DATE '2018-08-30' - MAX(o.order_purchase_timestamp)::DATE AS recency,
	COUNT(DISTINCT ot.order_id) AS frequency,
	SUM(ot.price) AS monetary
FROM order_items ot
LEFT JOIN orders o
	ON ot.order_id = o.order_id
LEFT JOIN customers c
	ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_unique_id
)
SELECT
	customer_unique_id,
	NTILE(4) OVER (ORDER BY recency DESC) AS recency_score,
	NTILE(4) OVER (ORDER BY frequency) AS frequency_score,
	NTILE(4) OVER (ORDER BY monetary) AS monetary_score
FROM customer_performance;

-- Frequency score validation: compare purchase counts across scoring groups
WITH customer_performance AS (
SELECT
	c.customer_unique_id,
	DATE '2018-08-30' - MAX(o.order_purchase_timestamp)::DATE AS recency,
	COUNT(DISTINCT ot.order_id) AS frequency,
	SUM(ot.price) AS monetary
FROM order_items ot
LEFT JOIN orders o
	ON ot.order_id = o.order_id
LEFT JOIN customers c
	ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_unique_id
),
rfm_scoring AS (
SELECT
	customer_unique_id,
	NTILE(4) OVER (ORDER BY recency DESC) AS recency_score,
	NTILE(4) OVER (ORDER BY frequency) AS frequency_score,
	NTILE(4) OVER (ORDER BY monetary) AS monetary_score
FROM customer_performance
)
SELECT 
	frequency_score,
	MIN(frequency),
	MAX(frequency) 
FROM customer_performance cp
INNER JOIN rfm_scoring rs
	ON cp.customer_unique_id = rs.customer_unique_id
GROUP BY rs.frequency_score
ORDER BY rs.frequency_score;


-- Final RFM scoring: apply custom frequency thresholds and create combined RFM identifiers
WITH customer_performance AS (
SELECT
	c.customer_unique_id,
	DATE '2018-08-30' - MAX(o.order_purchase_timestamp)::DATE AS recency,
	COUNT(DISTINCT ot.order_id) AS frequency,
	SUM(ot.price) AS monetary
FROM order_items ot
LEFT JOIN orders o
	ON ot.order_id = o.order_id
LEFT JOIN customers c
	ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_unique_id
),
rfm_scoring AS (
SELECT
	customer_unique_id,
	NTILE(4) OVER (ORDER BY recency DESC) AS recency_score,
	CASE
		WHEN frequency = 1 THEN 1
		WHEN frequency = 2 THEN 2
		WHEN frequency IN (3,4) THEN 3
 		ELSE 4
	END AS frequency_score,
	NTILE(4) OVER (ORDER BY monetary) AS monetary_score
FROM customer_performance
)
SELECT
	customer_unique_id,
	CONCAT(recency_score, frequency_score, monetary_score) AS rfm_identifier
FROM rfm_scoring;

-- Count customers by RFM profile
WITH customer_performance AS (
SELECT
	c.customer_unique_id,
	DATE '2018-08-30' - MAX(o.order_purchase_timestamp)::DATE AS recency,
	COUNT(DISTINCT ot.order_id) AS frequency,
	SUM(ot.price) AS monetary
FROM order_items ot
LEFT JOIN orders o
	ON ot.order_id = o.order_id
LEFT JOIN customers c
	ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_unique_id
),
rfm_scoring AS (
SELECT
	customer_unique_id,
	NTILE(4) OVER (ORDER BY recency DESC) AS recency_score,
	CASE
		WHEN frequency = 1 THEN 1
		WHEN frequency = 2 THEN 2
		WHEN frequency IN (3,4) THEN 3
 		ELSE 4
	END AS frequency_score,
	NTILE(4) OVER (ORDER BY monetary) AS monetary_score
FROM customer_performance
),
rfm_identifier AS (
	SELECT
		customer_unique_id,
		CONCAT(recency_score, frequency_score, monetary_score) AS rfm_identifier
	FROM rfm_scoring
)
SELECT 
	rfm_identifier,
	COUNT(customer_unique_id) AS total_customers
FROM rfm_identifier
GROUP BY rfm_identifier
ORDER BY total_customers DESC;
	

-- Customer segmentation: assign business labels based on RFM scores
CREATE OR REPLACE VIEW public.vw_rfm_customer_segments AS
WITH customer_performance AS (
SELECT
	c.customer_unique_id,
	DATE '2018-08-30' - MAX(o.order_purchase_timestamp)::DATE AS recency,
	COUNT(DISTINCT ot.order_id) AS frequency,
	SUM(ot.price) AS monetary
FROM order_items ot
LEFT JOIN orders o
	ON ot.order_id = o.order_id
LEFT JOIN customers c
	ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_unique_id
),
rfm_scoring AS (
SELECT
	customer_unique_id,
	NTILE(4) OVER (ORDER BY recency DESC) AS recency_score,
	CASE
		WHEN frequency = 1 THEN 1
		WHEN frequency = 2 THEN 2
		WHEN frequency IN (3,4) THEN 3
 		ELSE 4
	END AS frequency_score,
	NTILE(4) OVER (ORDER BY monetary) AS monetary_score
FROM customer_performance
)
SELECT 
	customer_unique_id,
    recency_score,
    frequency_score,
    monetary_score,
    CONCAT(recency_score, frequency_score, monetary_score) AS rfm_identifier,
	CASE
		WHEN recency_score = 1 AND (frequency_score >= 2 OR monetary_score >= 3) THEN 'At risk'
		WHEN recency_score = 1 AND frequency_score = 1 AND monetary_score <= 2 THEN 'Hibernating'
		WHEN recency_score = 4 AND frequency_score = 1 THEN 'New customers'
		WHEN recency_score = 4 AND frequency_score = 4 AND monetary_score = 4 THEN 'Champions'
		WHEN recency_score >= 3 AND frequency_score >= 3 THEN 'Loyal customers'
		ELSE 'Others'
	END AS customer_label
FROM rfm_scoring;

-- Customer segment distribution: count customers in each RFM segment
CREATE OR REPLACE VIEW public.vw_rfm_segment_distribution AS
WITH customer_performance AS (
SELECT
	c.customer_unique_id,
	DATE '2018-08-30' - MAX(o.order_purchase_timestamp)::DATE AS recency,
	COUNT(DISTINCT ot.order_id) AS frequency,
	SUM(ot.price) AS monetary
FROM order_items ot
LEFT JOIN orders o
	ON ot.order_id = o.order_id
LEFT JOIN customers c
	ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_unique_id
),
rfm_scoring AS (
SELECT
	customer_unique_id,
	NTILE(4) OVER (ORDER BY recency DESC) AS recency_score,
	CASE
		WHEN frequency = 1 THEN 1
		WHEN frequency = 2 THEN 2
		WHEN frequency IN (3,4) THEN 3
 		ELSE 4
	END AS frequency_score,
	NTILE(4) OVER (ORDER BY monetary) AS monetary_score
FROM customer_performance
),
customer_labels AS (
	SELECT 
		customer_unique_id,
		CASE
			WHEN recency_score = 1 AND (frequency_score >= 2 OR monetary_score >= 3) THEN 'At risk'
			WHEN recency_score = 1 AND frequency_score = 1 AND monetary_score <= 2 THEN 'Hibernating'
			WHEN recency_score = 4 AND frequency_score = 1 THEN 'New customers'
			WHEN recency_score = 4 AND frequency_score = 4 AND monetary_score = 4 THEN 'Champions'
			WHEN recency_score >= 3 AND frequency_score >= 3 THEN 'Loyal customers'
			ELSE 'Others'
		END AS customer_label
	FROM rfm_scoring
)
SELECT 
	customer_label,
	COUNT(*) AS total_customers
FROM customer_labels
GROUP BY customer_label
ORDER BY total_customers DESC

