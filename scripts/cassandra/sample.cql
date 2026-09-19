SELECT customer_id, order_date, order_id, status FROM orders_by_customer WHERE customer_id = 1 LIMIT 3;
SELECT sum(line_total) AS books_delivered FROM order_lines_by_category WHERE category = 'Books' AND status = 'delivered';
