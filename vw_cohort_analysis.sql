-- Diagnóstico: Clientes Únicos vs. Volume de Pedidos Válidos
SELECT 
    COUNT(DISTINCT c.customer_unique_id) AS total_unique_customers,
    COUNT(DISTINCT o.order_id) AS total_delivered_orders
FROM orders o
JOIN customers c 
    ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered';




WITH customer_first_order AS (
    -- 1. Identifica a data do primeiro pedido entregue de cada cliente único
    SELECT 
        c.customer_unique_id,
        MIN(o.order_purchase_timestamp) AS first_purchase_date
    FROM orders o
    JOIN customers c 
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),

orders_consolidated AS (
    -- 2. Une com todos os pedidos entregues para calcular os meses decorridos e a receita
    SELECT 
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp,
        cfo.first_purchase_date,
        -- Truncando para o primeiro dia do mês da primeira compra (Safra)
        DATE_TRUNC('month', cfo.first_purchase_date)::date AS cohort_month,
        -- Truncando para o primeiro dia do mês da compra do pedido em questão
        DATE_TRUNC('month', o.order_purchase_timestamp)::date AS order_month
    FROM orders o
    JOIN customers c 
        ON o.customer_id = c.customer_id
    JOIN customer_first_order cfo 
        ON c.customer_unique_id = cfo.customer_unique_id
    WHERE o.order_status = 'delivered'
)

-- 3. Projeção com o Cohort Index (diferença em meses entre o pedido atual e a primeira compra)
SELECT 
    order_id,
    customer_unique_id,
    order_purchase_timestamp,
    cohort_month,
    order_month,
    -- Cálculo do índice do mês (Ano_dif * 12 + Mês_dif)
    (EXTRACT(YEAR FROM order_month) - EXTRACT(YEAR FROM cohort_month)) * 12 +
    (EXTRACT(MONTH FROM order_month) - EXTRACT(MONTH FROM cohort_month)) AS cohort_index
FROM orders_consolidated
ORDER BY customer_unique_id, order_purchase_timestamp
LIMIT 50;



WITH customer_first_order AS (
    SELECT 
        c.customer_unique_id,
        MIN(o.order_purchase_timestamp) AS first_purchase_date
    FROM orders o
    JOIN customers c 
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
orders_consolidated AS (
    SELECT 
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp,
        cfo.first_purchase_date,
        DATE_TRUNC('month', cfo.first_purchase_date)::date AS cohort_month,
        DATE_TRUNC('month', o.order_purchase_timestamp)::date AS order_month
    FROM orders o
    JOIN customers c 
        ON o.customer_id = c.customer_id
    JOIN customer_first_order cfo 
        ON c.customer_unique_id = cfo.customer_unique_id
    WHERE o.order_status = 'delivered'
)
SELECT 
    (EXTRACT(YEAR FROM order_month) - EXTRACT(YEAR FROM cohort_month)) * 12 +
    (EXTRACT(MONTH FROM order_month) - EXTRACT(MONTH FROM cohort_month)) AS cohort_index,
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT customer_unique_id) AS unique_customers
FROM orders_consolidated
GROUP BY 1
ORDER BY 1;



CREATE OR REPLACE VIEW vw_cohort_analysis AS
WITH customer_first_order AS (
    SELECT 
        c.customer_unique_id,
        MIN(o.order_purchase_timestamp) AS first_purchase_date
    FROM orders o
    JOIN customers c 
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),

order_financials AS (
    SELECT 
        order_id,
        SUM(price) AS total_items_value,
        SUM(freight_value) AS total_freight_value,
        SUM(price + freight_value) AS total_order_value
    FROM order_items
    GROUP BY order_id
)

SELECT 
    o.order_id,
    c.customer_unique_id,
    o.order_purchase_timestamp,
    cfo.first_purchase_date,
    DATE_TRUNC('month', cfo.first_purchase_date)::date AS cohort_month,
    DATE_TRUNC('month', o.order_purchase_timestamp)::date AS order_month,
    (EXTRACT(YEAR FROM DATE_TRUNC('month', o.order_purchase_timestamp)) - EXTRACT(YEAR FROM DATE_TRUNC('month', cfo.first_purchase_date))) * 12 +
    (EXTRACT(MONTH FROM DATE_TRUNC('month', o.order_purchase_timestamp)) - EXTRACT(MONTH FROM DATE_TRUNC('month', cfo.first_purchase_date))) AS cohort_index,
    COALESCE(ofin.total_items_value, 0) AS total_items_value,
    COALESCE(ofin.total_freight_value, 0) AS total_freight_value,
    COALESCE(ofin.total_order_value, 0) AS total_order_value
FROM orders o
JOIN customers c 
    ON o.customer_id = c.customer_id
JOIN customer_first_order cfo 
    ON c.customer_unique_id = cfo.customer_unique_id
LEFT JOIN order_financials ofin 
    ON o.order_id = ofin.order_id
WHERE o.order_status = 'delivered';



SELECT 
    COUNT(DISTINCT customer_unique_id) AS total_customers,
    COUNT(DISTINCT order_id) AS total_orders,
    ROUND(SUM(total_order_value), 2) AS total_revenue,
    ROUND(AVG(total_order_value), 2) AS overall_avg_ticket
FROM vw_cohort_analysis;