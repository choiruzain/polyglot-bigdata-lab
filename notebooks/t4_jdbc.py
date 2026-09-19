import os
from pyspark.sql import SparkSession

spark = SparkSession.builder.appName("t4-jdbc").enableHiveSupport().getOrCreate()

pg = dict(url="jdbc:postgresql://postgres:5432/shop", user="student",
          password=os.environ["POSTGRES_PASSWORD"], driver="org.postgresql.Driver")
my = dict(url="jdbc:mysql://mysql:3306/shop", user="student",
          password=os.environ["MYSQL_PASSWORD"], driver="com.mysql.cj.jdbc.Driver")

orders = spark.read.format("jdbc").options(**pg, dbtable="orders").load()
customers = spark.read.format("jdbc").options(**my, dbtable="customers").load()
orders.createOrReplaceTempView("pg_orders")
customers.createOrReplaceTempView("my_customers")
print("PG_ORDERS", orders.count())
print("MYSQL_CUSTOMERS", customers.count())

rows = spark.sql("""
    SELECT c.city, ROUND(SUM(oi.quantity * p.price), 2) AS revenue
    FROM pg_orders o
    JOIN my_customers c ON c.id = o.customer_id
    JOIN shop.order_items oi ON oi.order_id = o.id
    JOIN shop.products p ON p.id = oi.product_id
    WHERE o.status = 'delivered'
    GROUP BY c.city ORDER BY c.city""").collect()
for r in rows:
    print("CITY_REVENUE", r["city"], r["revenue"])

fed = round(sum(float(r["revenue"]) for r in rows), 2)
hive = spark.sql("""
    SELECT ROUND(SUM(oi.quantity * p.price), 2)
    FROM shop.order_items oi
    JOIN shop.products p ON p.id = oi.product_id
    JOIN shop.orders o ON o.id = oi.order_id
    WHERE o.status = 'delivered'""").first()[0]
print("TOTAL_FEDERATED", fed)
print("TOTAL_HIVE_ONLY", hive)
spark.stop()
