# 📊 Сквозной SQL-анализ e-commerce платформы

> Операционные и финансовые инсайты из данных e-commerce: маркетинг, возвраты, логистика, продавцы, товары.

---

## 🎯 Бизнес-цель

Извлечь практические инсайты из сырых данных e-commerce платформы для поддержки операционных и финансовых решений:

- Оптимизация распределения маркетингового бюджета по регионам
- Сокращение потерь от возвратов товаров
- Улучшение клиентского опыта через управление логистикой
- Выявление аномального поведения продавцов
- Приоритизация товарного ассортимента по вкладу в выручку

---

## 🗂️ Структура базы данных


**Таблицы фактов:**

| Таблица | Описание |
|---|---|
| `FACT_ORDERS` | Транзакционные данные по заказам |
| `FACT_RETURNS` | Записи о возвратах товаров |
| `FACT_MARKETING_SPEND` | Расходы на кампании и атрибуция |
| `FACT_FULFILLMENT_PERFORMANCE` | KPI доставки и логистики |
| `FACT_CUSTOMER_RFM` | Сегментация клиентов (Recency, Frequency, Monetary) |

**Таблицы измерений:**

`dim_customer` · `dim_product` · `dim_seller` · `dim_location` · `dim_channel` · `dim_campaign` · `dim_calendar` · `dim_payment` · `dim_fulfillment` · `dim_delivery_personnel`

---

## 📁 Структура репозитория

```
├── scripts/
│   ├── 01_roas_analysis.sql          # ROAS по регионам
│   ├── 02_returns_by_category.sql    # Потери от возвратов
│   ├── 03_delivery_impact.sql        # Задержки и клиентский опыт
│   ├── 04_seller_anomalies.sql       # Аномалии у продавцов
│   └── 05_abc_analysis.sql           # ABC-анализ товаров
└── README.md
```

---

## 📈 Реализованные сценарии

### 1. Региональный ROAS — окупаемость маркетинга по городам

**Вопрос:** Какие регионы дают наибольшую отдачу от рекламных вложений, а какие работают в убыток?

Запрос связывает заказы с маркетинговыми расходами через кампанию и геолокацию, вычисляя ROAS как отношение выручки к затратам.

```sql
SELECT 
    l.city,
    l.state,
    SUM(m.spend_amount) AS marketing_costs,
    SUM(o.net_amount)   AS sales_revenue,
    ROUND((SUM(o.net_amount) / NULLIF(SUM(m.spend_amount), 0))::numeric, 2) AS roas
FROM dim_location l
JOIN fact_orders o          ON l.location_id = o.location_id
JOIN fact_marketing_spend m ON o.campaign_id = m.campaign_id
GROUP BY l.city, l.state
ORDER BY roas DESC;
```

---

### 2. Потери от возвратов по категориям товаров

**Вопрос:** Какие категории генерируют больше всего возвратов и упущенной выручки?

Подзапрос агрегирует заказы по категориям, считая процент возвратов и сумму потерь; во внешнем запросе добавляется округление для читаемости.

```sql
SELECT 
    category,
    total_orders,
    lost_revenue,
    ROUND((return_count::numeric / NULLIF(total_orders, 0)) * 100, 2) AS return_rate_pct,
    ROUND(avg_seller_rating::numeric, 2)                               AS avg_seller_rating
FROM (
    SELECT 
        p.category,
        COUNT(o.order_id)                                                          AS total_orders,
        SUM(CASE WHEN o.return_flag = 'True' THEN 1 ELSE 0 END)                   AS return_count,
        SUM(CASE WHEN o.return_flag = 'True' THEN o.refund_amount ELSE 0 END)     AS lost_revenue,
        AVG(s.rating)                                                              AS avg_seller_rating
    FROM fact_orders o
    JOIN dim_product p ON o.product_id = p.product_id
    JOIN dim_seller  s ON o.seller_id  = s.seller_id
    GROUP BY p.category
)
ORDER BY lost_revenue DESC;
```

---

### 3. Влияние задержек доставки на лояльность клиентов

**Вопрос:** Где находится критическая точка падения лояльности в зависимости от длительности задержки?

CTE `delay_segments` сегментирует заказы по дням задержки, `stats` считает средние оценки, финальный SELECT добавляет глобальное среднее и отклонение через оконную функцию.

```sql
WITH delay_segments AS (
    SELECT 
        delivery_delay_days,
        sentiment_score,
        customer_rating,
        CASE 
            WHEN delivery_delay_days = 0              THEN 'Вовремя'
            WHEN delivery_delay_days = 1              THEN '1 день задержки'
            WHEN delivery_delay_days = 2              THEN '2 дня'
            WHEN delivery_delay_days BETWEEN 3 AND 5  THEN '3–5 дней'
            WHEN delivery_delay_days > 5              THEN 'Более 5 дней'
        END AS delay_segment
    FROM fact_orders
    WHERE sentiment_score IS NOT NULL
),
stats AS (
    SELECT 
        delay_segment,
        ROUND(AVG(sentiment_score)::numeric, 4) AS avg_sentiment,
        ROUND(AVG(customer_rating)::numeric, 4) AS avg_rating
    FROM delay_segments
    GROUP BY delay_segment
)
SELECT 
    *,
    ROUND(AVG(avg_rating) OVER(), 4)              AS global_avg_rating,
    ROUND(avg_rating - AVG(avg_rating) OVER(), 2) AS rating_deviation
FROM stats
ORDER BY delay_segment;
```

---

### 4. Выявление аномалий: продавцы с высоким процентом возвратов

**Вопрос:** Какие продавцы имеют долю возвратов на 50%+ выше среднего по своей категории?

Оконные функции `OVER (PARTITION BY seller_id)` и `OVER (PARTITION BY category)` считают средний возврат на двух уровнях прямо внутри GROUP BY через вложенные агрегаты.

```sql
WITH seller_stats AS (
    SELECT 
        o.seller_id,
        s.seller_name,
        p.category,  -- добавить join с dim_product при необходимости
        SUM(CASE WHEN o.return_flag = 'True' THEN 1 ELSE 0 END) AS count_return,
        COUNT(o.return_flag)                                     AS count_orders,
        ROUND(
            AVG(SUM(CASE WHEN o.return_flag = 'True' THEN 1 ELSE 0 END)::numeric
                / COUNT(o.return_flag) * 100)
            OVER (PARTITION BY o.seller_id), 2
        ) AS seller_avg_return_rate,
        ROUND(
            AVG(SUM(CASE WHEN o.return_flag = 'True' THEN 1 ELSE 0 END)::numeric
                / COUNT(o.return_flag) * 100)
            OVER (PARTITION BY s.category), 2
        ) AS category_avg_return_rate
    FROM fact_orders o
    JOIN dim_seller s USING (seller_id)
    GROUP BY o.seller_id, s.seller_name, s.category
)
SELECT *
FROM seller_stats
WHERE seller_avg_return_rate > category_avg_return_rate * 1.5
ORDER BY category, count_return DESC;
```

---

### 5. ABC-анализ товарной матрицы по выручке

**Вопрос:** Какие товары формируют 80% выручки (A), а какие приносят минимум дохода при затратах на хранение (C)?

Три слоя CTE: агрегация выручки → накопленная сумма через `SUM() OVER` → вычисление кумулятивного процента. Итоговый SELECT присваивает категорию A/B/C.

```sql
WITH product_revenue AS (
    SELECT 
        product_id,
        product_name,
        SUM(net_amount) AS total_revenue
    FROM fact_orders
    JOIN dim_product USING (product_id)
    GROUP BY product_id, product_name
),
cumulative_stats AS (
    SELECT 
        *,
        SUM(total_revenue) OVER (ORDER BY total_revenue DESC) AS cumulative_revenue,
        SUM(total_revenue) OVER ()                            AS grand_total
    FROM product_revenue
),
percentage_calc AS (
    SELECT 
        *,
        cumulative_revenue / grand_total AS cumulative_pct
    FROM cumulative_stats
)
SELECT 
    product_id,
    product_name,
    ROUND(total_revenue::numeric,    2) AS revenue,
    ROUND(cumulative_revenue::numeric, 2) AS cumulative_revenue,
    CASE
        WHEN cumulative_pct <= 0.80 THEN 'A'
        WHEN cumulative_pct <= 0.95 THEN 'B'
        ELSE 'C'
    END AS abc_category
FROM percentage_calc;
```


