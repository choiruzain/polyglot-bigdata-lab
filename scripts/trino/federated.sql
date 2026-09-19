-- Revenue per city, joining four different engines in one query:
-- orders (PostgreSQL), order lines (ClickHouse), products (MySQL), customers (Cassandra)
SELECT c.city, round(sum(oi.quantity * p.price), 2) AS revenue
FROM postgresql.public.orders o
JOIN clickhouse.shop.order_items oi ON oi.order_id = o.id
JOIN mysql.shop.products p ON p.id = oi.product_id
JOIN cassandra.shop.customers c ON c.id = o.customer_id
WHERE o.status = 'delivered'
GROUP BY c.city
ORDER BY c.city;
