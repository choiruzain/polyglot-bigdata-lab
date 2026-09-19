SELECT 'postgresql.orders' AS source, count(*) AS row_count FROM postgresql.public.orders
UNION ALL SELECT 'mysql.customers', count(*) FROM mysql.shop.customers
UNION ALL SELECT 'mongodb.orders', count(*) FROM mongodb.shop.orders
UNION ALL SELECT 'cassandra.orders_by_customer', count(*) FROM cassandra.shop.orders_by_customer
UNION ALL SELECT 'clickhouse.order_items', count(*) FROM clickhouse.shop.order_items;
