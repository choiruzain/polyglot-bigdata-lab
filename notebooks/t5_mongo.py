import os
from pyspark.sql import SparkSession

uri = f"mongodb://student:{os.environ['MONGO_PASSWORD']}@mongo:27017/?authSource=shop"
spark = (SparkSession.builder.appName("t5-mongo").enableHiveSupport()
         .config("spark.mongodb.read.connection.uri", uri)
         .config("spark.mongodb.read.database", "shop").getOrCreate())

orders = spark.read.format("mongodb").option("collection", "orders").load()
products = spark.read.format("mongodb").option("collection", "products").load()
orders.createOrReplaceTempView("mg_orders")
products.createOrReplaceTempView("mg_products")
print("MONGO_ORDERS", orders.count())
print("MONGO_PRODUCTS", products.count())
print("PRICE_TYPE", dict(products.dtypes)["price"])

flat = "(SELECT status, explode(items) AS it FROM mg_orders WHERE status = 'delivered') o"
for r in spark.sql(f"""
    SELECT p.category, ROUND(SUM(o.it.quantity * p.price), 2) AS revenue
    FROM {flat} JOIN mg_products p ON p.`_id` = o.it.product_id
    GROUP BY p.category ORDER BY p.category""").collect():
    print("CATEGORY", r["category"], r["revenue"])

a = spark.sql(f"""SELECT ROUND(SUM(o.it.quantity * p.price), 2)
    FROM {flat} JOIN mg_products p ON p.`_id` = o.it.product_id""").first()[0]
b = spark.sql(f"""SELECT ROUND(SUM(o.it.quantity * p.price), 2)
    FROM {flat} JOIN shop.products p ON p.id = o.it.product_id""").first()[0]
print("TOTAL_MONGO_ONLY", a)
print("TOTAL_MONGO_PLUS_HIVE", b)
spark.stop()
