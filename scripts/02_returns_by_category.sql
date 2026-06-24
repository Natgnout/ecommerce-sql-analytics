SELECT 
    category,
    total_orders,
    lost_revenue,
    ROUND((return_count::numeric / NULLIF(total_orders, 0)) * 100, 2) AS return_rate_pct,
    ROUND(avg_seller_rating::numeric, 2) AS avg_seller_rating
FROM (
	SELECT 
		p.category,
		COUNT(o.order_id) AS total_orders,
		SUM(CASE WHEN o.return_flag = 'True' THEN 1 ELSE 0 END) AS return_count,
		SUM(CASE WHEN o.return_flag = 'True' THEN o.refund_amount ELSE 0 END) AS lost_revenue,
		AVG(s.rating) AS avg_seller_rating
	FROM fact_orders o
	JOIN dim_product p ON o.product_id = p.product_id
	JOIN dim_seller s  ON o.seller_id = s.seller_id
	GROUP BY p.category
)
ORDER BY lost_revenue DESC;
