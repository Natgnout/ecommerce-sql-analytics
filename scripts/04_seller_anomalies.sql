WITH A AS(
SELECT 	
    seller_id, 
    seller_name,
    category,
    SUM(CASE WHEN return_flag = 'True' THEN 1 ELSE 0 END) AS count_return,
    COUNT(return_flag) AS count_payment,

	ROUND(
        AVG(SUM(CASE WHEN return_flag = 'True' THEN 1 ELSE 0 END)::numeric / COUNT(return_flag) * 100) 
        OVER (PARTITION BY seller_id), 2
    ) AS seller_avg_return_rate,
	
    ROUND(
        AVG(SUM(CASE WHEN return_flag = 'True' THEN 1 ELSE 0 END)::numeric / COUNT(return_flag) * 100) 
        OVER (PARTITION BY category), 2
    ) AS category_avg_return_rate
FROM fact_orders o
JOIN dim_seller s USING(seller_id)
GROUP BY seller_id, seller_name, category
)

SELECT * FROM A
WHERE seller_avg_return_rate > category_avg_return_rate*1.5
ORDER BY category, count_return DESC
