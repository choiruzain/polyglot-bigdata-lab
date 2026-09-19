SELECT p.category, round(sum(oi.quantity * p.price), 2) AS revenue
FROM order_items AS oi
JOIN products AS p ON p.id = oi.product_id
JOIN orders AS o ON o.id = oi.order_id
WHERE o.status = 'delivered'
GROUP BY p.category ORDER BY p.category;

SELECT `table`, sum(rows) AS rows, formatReadableSize(sum(data_compressed_bytes)) AS compressed, formatReadableSize(sum(data_uncompressed_bytes)) AS uncompressed
FROM system.parts WHERE database = 'shop' AND active GROUP BY `table` ORDER BY `table`;
