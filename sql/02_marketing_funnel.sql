-- Calculate the overall lead-to-closed-deal conversion rate (%)
SELECT
	COUNT(*) AS total_leads,
	COUNT(cd.mql_id) AS closed_deals,
	COUNT(*) - COUNT(cd.mql_id) AS not_closed_deals,
	ROUND(COUNT(cd.mql_id) * 100.0 / COUNT(*), 2)  AS conversion_rate
	FROM marketing_qualified_leads ml
LEFT JOIN closed_deals cd
	ON ml.mql_id = cd.mql_id;

-- Lead conversion rate by origin
SELECT
	origin,
	COUNT(*) AS total_leads,
	COUNT(cd.mql_id) AS closed_deals,
	ROUND(COUNT(cd.mql_id) * 100.0 / COUNT(*), 2)  AS conversion_rate
FROM marketing_qualified_leads ml
LEFT JOIN closed_deals cd
	ON ml.mql_id = cd.mql_id
GROUP BY origin
ORDER BY closed_deals DESC;

-- Lead conversion rate by landing page
SELECT
    landing_page_id,
    COUNT(*) AS total_leads,
    COUNT(cd.mql_id) AS closed_deals,
    ROUND(COUNT(cd.mql_id) * 100.0 / COUNT(*), 2) AS conversion_rate
FROM marketing_qualified_leads ml
LEFT JOIN closed_deals cd
    ON ml.mql_id = cd.mql_id
GROUP BY landing_page_id
ORDER BY closed_deals DESC;

-- Landing page performance (minimum 100 leads)
SELECT 
	landing_page_id,
	COUNT(*) AS total_leads,
    COUNT(cd.mql_id) AS closed_deals,
    ROUND(COUNT(cd.mql_id) * 100.0 / COUNT(*), 2) AS conversion_rate
FROM marketing_qualified_leads ml
LEFT JOIN closed_deals cd
    ON ml.mql_id = cd.mql_id
GROUP BY landing_page_id
HAVING COUNT(*) > 100
ORDER BY closed_deals DESC;

-- Time to close - individual lead conversion time
SELECT
	ml.mql_id,
	ml.first_contact_date,
	cd.won_date,
	cd.won_date::DATE - ml.first_contact_date AS days_from_contact_to_deal
FROM marketing_qualified_leads ml
INNER JOIN closed_deals cd
    ON ml.mql_id = cd.mql_id;

-- Average time from first contact to closed deal (days)
SELECT
	ROUND(AVG(cd.won_date::DATE - ml.first_contact_date), 2) AS avg_days_to_close
	FROM marketing_qualified_leads ml
INNER JOIN closed_deals cd
    ON ml.mql_id = cd.mql_id;

-- Median time from first contact to closed deal (days)
WITH lead_times AS (
	SELECT 
		cd.won_date::DATE - ml.first_contact_date AS days
	FROM marketing_qualified_leads ml
	INNER JOIN closed_deals cd
    	ON ml.mql_id = cd.mql_id
)

SELECT 
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY days) AS median_days_to_close
FROM lead_times;

-- Average and median time to close by lead source
SELECT 
	origin,
	COUNT(cd.mql_id) AS closed_deals,
	ROUND(AVG(cd.won_date::DATE - ml.first_contact_date), 2) AS avg_days_to_close,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY cd.won_date::DATE - ml.first_contact_date) AS median_days_to_close
FROM marketing_qualified_leads ml
INNER JOIN closed_deals cd
	ON ml.mql_id = cd.mql_id
GROUP BY origin;

-- Average and median time to close by business segment
SELECT
	business_segment,
	COUNT(cd.mql_id) AS closed_deals,
	ROUND(AVG(cd.won_date::DATE - ml.first_contact_date), 2) AS avg_days_to_close,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY cd.won_date::DATE - ml.first_contact_date) AS median_days_to_close
FROM closed_deals cd
INNER JOIN marketing_qualified_leads ml
	ON cd.mql_id = ml.mql_id
GROUP BY business_segment
ORDER BY closed_deals DESC;

-- Closed deals by lead type
SELECT
	lead_type,
	COUNT(*) AS closed_deals,
	ROUND(AVG(declared_monthly_revenue), 2) AS avg_monthly_revenue,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY declared_monthly_revenue) AS median_monthly_revenue,
	ROUND(AVG(declared_product_catalog_size), 2) AS avg_catalog_size
FROM closed_deals
GROUP BY lead_type
ORDER BY closed_deals DESC;

-- Check declared monthly revenue distribution by lead type
SELECT
	lead_type,
	COUNT(*) AS total_deals,
	COUNT(*) FILTER (WHERE declared_monthly_revenue IS NULL) AS null_declared_revenue,
	COUNT(declared_monthly_revenue) FILTER (WHERE declared_monthly_revenue = 0) AS zero_declared_revenue,
	COUNT(declared_monthly_revenue) FILTER (WHERE declared_monthly_revenue > 0) AS more_than_0_declared_revenue
FROM closed_deals
GROUP BY lead_type
ORDER BY COUNT(*) DESC;

-- Check declared product catalog size distribution
SELECT
	COUNT(*) AS total_deals,
	COUNT(*) FILTER (WHERE declared_product_catalog_size IS NULL) AS null_declared_catalog_size,
	COUNT(declared_product_catalog_size) FILTER (WHERE declared_product_catalog_size = 0) AS zero_declared_catalog_size,
	COUNT(declared_product_catalog_size) FILTER (WHERE declared_product_catalog_size > 0) AS more_than_0_declared_catalog_size
FROM closed_deals;

-- Check missing values in business segment and lead type
SELECT 
	COUNT(*) AS total_deals,
	COUNT(*) FILTER (WHERE business_segment IS NULL) AS null_business_segment,
	COUNT(*) FILTER (WHERE lead_type IS NULL) AS null_lead_type
FROM closed_deals;

-- Seller activation: closed deals vs marketplace sellers
SELECT
	COUNT(*) AS total_closed_deals,
	COUNT(s.seller_id) AS matched_sellers,
	COUNT(*) - COUNT(s.seller_id) AS unmatched_sellers,
	ROUND(COUNT(s.seller_id) * 100.0 / COUNT(*), 2) AS activation_rate
FROM closed_deals cd
LEFT JOIN sellers s
	ON cd.seller_id = s.seller_id;

-- Seller activity: closed-deal sellers with at least one order item
SELECT
	COUNT(DISTINCT s.seller_id) AS matched_sellers,
	COUNT(DISTINCT oi.seller_id) AS sellers_with_orders,
	COUNT(DISTINCT s.seller_id) - COUNT(DISTINCT oi.seller_id) AS sellers_without_orders
FROM closed_deals cd
INNER JOIN sellers s
	ON cd.seller_id = s.seller_id
LEFT JOIN order_items oi
	ON s.seller_id = oi.seller_id;

-- Marketplace performance: delivered orders and GMV
SELECT
	COUNT(DISTINCT o.order_id) AS total_delivered_orders,
	SUM(oi.price) AS GMV,
	ROUND(SUM(oi.price) / COUNT(DISTINCT o.order_id), 2) AS average_order_value
FROM closed_deals cd
INNER JOIN sellers s
	ON cd.seller_id = s.seller_id
LEFT JOIN order_items oi
	ON s.seller_id = oi.seller_id
LEFT JOIN orders o
	ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered';

-- Seller performance: delivered orders and GMV by seller
SELECT 
	s.seller_id,
	SUM(CASE WHEN o.order_id IS NOT NULL THEN oi.price ELSE 0 END) AS seller_gmv,
	COUNT(DISTINCT o.order_id) AS delivered_orders
FROM closed_deals cd
INNER JOIN sellers s
	ON cd.seller_id = s.seller_id
LEFT JOIN order_items oi
	ON s.seller_id = oi.seller_id
LEFT JOIN orders o
	ON oi.order_id = o.order_id AND o.order_status = 'delivered'
GROUP BY s.seller_id
ORDER BY seller_gmv DESC;

-- GMV concentration: top 10 sellers
WITH seller_performance AS (
	SELECT 
		s.seller_id,
		SUM(CASE WHEN o.order_id IS NOT NULL THEN oi.price ELSE 0 END) AS seller_gmv,
		COUNT(DISTINCT o.order_id) AS delivered_orders
	FROM closed_deals cd
	INNER JOIN sellers s
		ON cd.seller_id = s.seller_id
	LEFT JOIN order_items oi
		ON s.seller_id = oi.seller_id
	LEFT JOIN orders o
		ON oi.order_id = o.order_id AND o.order_status = 'delivered'
	GROUP BY s.seller_id
	ORDER BY seller_gmv DESC
),
top10_sellers AS (
	SELECT
	    seller_id,
	    seller_gmv,
	    delivered_orders
	FROM seller_performance
	ORDER BY seller_gmv DESC
	LIMIT 10
)
SELECT
	ROUND((SELECT SUM(seller_gmv) FROM seller_performance), 2) AS total_gmv,
	ROUND((SELECT SUM(seller_gmv) FROM top10_sellers), 2) AS top10_gmv,
	ROUND((SELECT SUM(seller_gmv) FROM top10_sellers) * 100.0 / (SELECT SUM(seller_gmv) FROM seller_performance), 2) AS top10_gmv_share;

-- Top 10 sellers: share of delivered orders
WITH seller_performance AS (
	SELECT 
		s.seller_id,
		SUM(CASE WHEN o.order_id IS NOT NULL THEN oi.price ELSE 0 END) AS seller_gmv,
		COUNT(DISTINCT o.order_id) AS delivered_orders
	FROM closed_deals cd
	INNER JOIN sellers s
		ON cd.seller_id = s.seller_id
	LEFT JOIN order_items oi
		ON s.seller_id = oi.seller_id
	LEFT JOIN orders o
		ON oi.order_id = o.order_id AND o.order_status = 'delivered'
	GROUP BY s.seller_id
	ORDER BY seller_gmv DESC
),
top10_sellers AS (
	SELECT
	    seller_id,
	    seller_gmv,
	    delivered_orders
	FROM seller_performance
	ORDER BY seller_gmv DESC
	LIMIT 10
)
SELECT 
	(SELECT SUM(delivered_orders) FROM seller_performance) AS total_delivered_orders,
	(SELECT SUM(delivered_orders) FROM top10_sellers) AS top10_delivered_orders,
	ROUND((SELECT SUM(delivered_orders) FROM top10_sellers) * 100.0 / (SELECT SUM(delivered_orders) FROM seller_performance), 2) AS top10_orders_share;

-- Seller segmentation: top 10 vs other sellers
WITH seller_performance AS (
	SELECT 
		s.seller_id,
		SUM(CASE WHEN o.order_id IS NOT NULL THEN oi.price ELSE 0 END) AS seller_gmv,
		COUNT(DISTINCT o.order_id) AS delivered_orders
	FROM closed_deals cd
	INNER JOIN sellers s
		ON cd.seller_id = s.seller_id
	LEFT JOIN order_items oi
		ON s.seller_id = oi.seller_id
	LEFT JOIN orders o
		ON oi.order_id = o.order_id AND o.order_status = 'delivered'
	GROUP BY s.seller_id
	ORDER BY seller_gmv DESC
),
top10_sellers AS (
	SELECT
	    seller_id,
	    seller_gmv,
	    delivered_orders
	FROM seller_performance
	ORDER BY seller_gmv DESC
	LIMIT 10
)
SELECT
	seller_id,
	seller_gmv,
	'top10_sellers' AS seller_group 
FROM top10_sellers

UNION ALL

SELECT
	seller_id,
	seller_gmv,
	'other_sellers' AS seller_group
FROM seller_performance
WHERE seller_id NOT IN (SELECT seller_id FROM top10_sellers);


-- Average order value (AOV): top 10 vs other sellers
WITH seller_performance AS (
	SELECT 
		s.seller_id,
		SUM(CASE WHEN o.order_id IS NOT NULL THEN oi.price ELSE 0 END) AS seller_gmv,
		COUNT(DISTINCT o.order_id) AS delivered_orders
	FROM closed_deals cd
	INNER JOIN sellers s
		ON cd.seller_id = s.seller_id
	LEFT JOIN order_items oi
		ON s.seller_id = oi.seller_id
	LEFT JOIN orders o
		ON oi.order_id = o.order_id AND o.order_status = 'delivered'
	GROUP BY s.seller_id
	ORDER BY seller_gmv DESC
),
top10_sellers AS (
	SELECT
	    seller_id,
	    seller_gmv,
	    delivered_orders
	FROM seller_performance
	ORDER BY seller_gmv DESC
	LIMIT 10
),
seller_groups AS (
SELECT
	seller_id,
	seller_gmv,
	delivered_orders,
	'top10_sellers' AS seller_group 
FROM top10_sellers

UNION ALL

SELECT
	seller_id,
	seller_gmv,
	delivered_orders,
	'other_sellers' AS seller_group
FROM seller_performance
WHERE seller_id NOT IN (SELECT seller_id FROM top10_sellers)
)
SELECT 
	seller_group,
	SUM(seller_gmv) AS total_gmv,
	SUM(delivered_orders) AS total_orders,
	ROUND(SUM(seller_gmv) / SUM(delivered_orders), 2) AS average_order_value
FROM seller_groups 
GROUP BY seller_group



	