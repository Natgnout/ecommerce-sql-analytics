WITH product_revenue AS(
	SELECT 
		product_id, 	
		product_name,
		SUM(net_amount) AS total_revenue	
	FROM fact_orders
	JOIN dim_product USING(product_id)
	GROUP BY product_id, product_name
),
cumulative_stats AS (
	SELECT 
		*,
		SUM(total_revenue) OVER (ORDER BY total_revenue DESC) AS cumulative_revenue,
		SUM(total_revenue) OVER () AS grand_total
	FROM product_revenue 
),
percentage_calc AS (
	SELECT 
	*,
	cumulative_revenue/grand_total AS cumulative_pct
FROM cumulative_stats 
)
SELECT 
	product_id,
	product_name,
	ROUND(total_revenue::numeric, 2) AS revenue, 
	ROUND(cumulative_revenue::numeric, 2) AS share_pct,
	CASE
		WHEN cumulative_pct <= 0.8 THEN 'A'
		WHEN cumulative_pct <= 0.95 THEN 'B'
		ELSE 'C'
	END AS abc_category
FROM percentage_calc
