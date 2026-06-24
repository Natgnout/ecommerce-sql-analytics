WITH delay_segments AS
(
	SELECT 
		delivery_delay_days,
		sentiment_score,
		customer_rating,
		CASE 	
			WHEN delivery_delay_days = 0 THEN 'Вовремя'
			WHEN delivery_delay_days = 1 THEN '1 день задержки'
			WHEN delivery_delay_days = 2 THEN '2 дня'
			WHEN delivery_delay_days BETWEEN 3 AND 5 THEN '3-5 дней'
			WHEN delivery_delay_days > 5 THEN 'Более 5 дней'
		END AS delay_priority
	FROM fact_orders
	WHERE sentiment_score IS NOT NULL
),
stats AS (
	SELECT 
		delay_priority,
		ROUND(AVG(sentiment_score)::numeric, 4) AS avg_sentiment, 
		ROUND(AVG(customer_rating)::numeric, 4) AS avg_rating 
	FROM delay_segments 
	GROUP BY delay_priority
)
SELECT 
    *,
    ROUND(AVG(avg_rating) OVER(), 4) AS global_avg_rating,
    ROUND(avg_rating - AVG(avg_rating) OVER(), 2) AS rating_deviation
FROM stats
ORDER BY delay_priority;
