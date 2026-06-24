SELECT 
    l.city,
    l.state,
    SUM(m.spend_amount) as marketing_costs,
    SUM(o.net_amount) as sales_revenue,
    ROUND((SUM(o.net_amount) / NULLIF(SUM(m.spend_amount), 0))::numeric, 2) as roas
FROM dim_location l
JOIN fact_orders o ON l.location_id = o.location_id
JOIN fact_marketing_spend m ON o.campaign_id = m.campaign_id
GROUP BY l.city, l.state
ORDER BY roas DESC;
