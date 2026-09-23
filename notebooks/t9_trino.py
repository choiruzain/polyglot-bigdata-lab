import os
import trino

conn = trino.dbapi.connect(
    host="trino",
    port=8080,
    user="student",
    catalog="postgresql",
)
cur = conn.cursor()

cur.execute("SHOW CATALOGS")
print("CATALOGS", [r[0] for r in cur.fetchall()])

cur.execute("""
    SELECT c.city, round(sum(oi.quantity * p.price), 2) AS revenue
    FROM postgresql.public.orders o
    JOIN clickhouse.shop.order_items oi ON oi.order_id = o.id
    JOIN mysql.shop.products p ON p.id = oi.product_id
    JOIN cassandra.shop.customers c ON c.id = o.customer_id
    WHERE o.status = 'delivered'
    GROUP BY c.city ORDER BY c.city
""")
rows = cur.fetchall()
total = 0.0
for city, revenue in rows:
    print("CITY", city, revenue)
    total += float(revenue)
print("TRINO_TOTAL", round(total, 2))
