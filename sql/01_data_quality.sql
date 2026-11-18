-- Lead conversion overview
SELECT
	COUNT(ml.mql_id) AS total_leads,
	COUNT(cd.mql_id) AS closed_deals,
	COUNT(ml.mql_id) - COUNT(cd.mql_id) AS not_closed_deals
FROM marketing_qualified_leads ml
LEFT JOIN closed_deals cd
	ON ml.mql_id = cd.mql_id;

-- Check for duplicate lead IDs
SELECT 'marketing_qualified_leads' AS table_name, COUNT(*) AS total_leads, COUNT(DISTINCT mql_id) AS unique_leads
FROM marketing_qualified_leads
UNION ALL
SELECT 'closed_deals', COUNT(*), COUNT(DISTINCT mql_id)
FROM closed_deals;
	
-- Check missing values in marketing_qualified_leads
SELECT 
	COUNT(*) FILTER (WHERE origin IS NULL) AS origin_null_total,
	COUNT(*) FILTER (WHERE mql_id IS NULL) AS mql_id_null_total,
	COUNT(*) FILTER (WHERE first_contact_date IS NULL) AS first_contact_date_null_total,
	COUNT(*) FILTER (WHERE landing_page_id IS NULL) AS landing_page_id_null_total
FROM marketing_qualified_leads;

-- Check missing values in closed_deals
SELECT
    COUNT(*) FILTER (WHERE mql_id IS NULL) AS mql_id_null_total,
    COUNT(*) FILTER (WHERE seller_id IS NULL) AS seller_id_null_total,
    COUNT(*) FILTER (WHERE won_date IS NULL) AS won_date_null_total
FROM closed_deals;

-- Check closed_deals seller IDs missing from sellers
SELECT
	COUNT(DISTINCT cd.seller_id)
FROM closed_deals cd
LEFT JOIN sellers s
	ON cd.seller_id = s.seller_id
WHERE s.seller_id IS NULL;


-- Check missing values in orders
SELECT
    COUNT(*) FILTER (WHERE order_id IS NULL) AS order_id_null,
    COUNT(*) FILTER (WHERE customer_id IS NULL) AS customer_id_null,
    COUNT(*) FILTER (WHERE order_status IS NULL) AS order_status_null,
    COUNT(*) FILTER (WHERE order_purchase_timestamp IS NULL) AS purchase_timestamp_null,
    COUNT(*) FILTER (WHERE order_approved_at IS NULL) AS approved_at_null,
    COUNT(*) FILTER (WHERE order_delivered_carrier_date IS NULL) AS carrier_date_null,
    COUNT(*) FILTER (WHERE order_delivered_customer_date IS NULL) AS delivered_date_null,
    COUNT(*) FILTER (WHERE order_estimated_delivery_date IS NULL) AS estimated_delivery_date_null
FROM orders;

-- Check order status distribution
SELECT
	order_status,
	COUNT(*) AS total_orders
FROM orders
GROUP BY order_status
ORDER BY total_orders DESC;

-- Check order status distribution for orders without delivery date
SELECT
	order_status,
	COUNT(*) FILTER (WHERE order_delivered_customer_date IS NULL) AS null_order_delivered_customer_date
FROM orders
GROUP BY order_status;

-- Identify delivered orders with missing delivery dates
SELECT *
FROM orders
WHERE order_delivered_customer_date IS NULL AND order_status = 'delivered';


-- Check missing values in customers
SELECT
    COUNT(*) FILTER (WHERE customer_unique_id IS NULL) AS customer_unique_id_null,
    COUNT(*) FILTER (WHERE customer_zip_code_prefix IS NULL) AS zip_code_null,
    COUNT(*) FILTER (WHERE customer_city IS NULL) AS customer_city_null,
    COUNT(*) FILTER (WHERE customer_state IS NULL) AS customer_state_null
FROM customers;

-- Check customer references between orders and customers
SELECT
	COUNT(*) FILTER (WHERE c.customer_id IS NULL)
FROM orders o
LEFT JOIN customers c
	ON 	o.customer_id = c.customer_id;

-- Check order_items record count and unique orders and sellers
SELECT
	COUNT(*) AS total_items,
	COUNT(DISTINCT order_id) AS unique_orders,
	COUNT(DISTINCT seller_id) AS unique_sellers,
	COUNT(DISTINCT (order_id, order_item_id)) 
FROM order_items;

-- Check missing values in order_items
SELECT
    COUNT(*) FILTER (WHERE order_id IS NULL) AS order_id_null,
    COUNT(*) FILTER (WHERE order_item_id IS NULL) AS order_item_id_null,
    COUNT(*) FILTER (WHERE product_id IS NULL) AS product_id_null,
    COUNT(*) FILTER (WHERE seller_id IS NULL) AS seller_id_null,
    COUNT(*) FILTER (WHERE shipping_limit_date IS NULL) AS shipping_limit_date_null,
    COUNT(*) FILTER (WHERE price IS NULL) AS price_null,
    COUNT(*) FILTER (WHERE freight_value IS NULL) AS freight_value_null
FROM order_items;

-- Check referential integrity between order_items and orders
SELECT
	COUNT(*) FILTER (WHERE o.order_id IS NULL) 
FROM order_items ot
LEFT JOIN orders o
	ON ot.order_id = o.order_id;

-- Check referential integrity between order_items and sellers
SELECT
	COUNT(*) FILTER (WHERE s.seller_id IS NULL)
FROM order_items ot
LEFT JOIN sellers s
	ON ot.seller_id = s.seller_id;

-- Check marketplace activity of closed deals missing from sellers
SELECT 
	COUNT(DISTINCT cd.seller_id) FILTER (WHERE ot.seller_id IS NULL)
FROM closed_deals cd
LEFT JOIN sellers s
    ON cd.seller_id = s.seller_id
LEFT JOIN order_items ot
	ON cd.seller_id = ot.seller_id
WHERE s.seller_id IS NULL;

---- Check seller IDs completeness and uniqueness in closed_deals
SELECT 
	COUNT(*) AS total_deals,
	COUNT(DISTINCT seller_id) AS total_sellers,
	COUNT(*) FILTER (WHERE seller_id IS NULL) AS null_seller_id
FROM closed_deals;



