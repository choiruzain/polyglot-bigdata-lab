from pyspark.sql import SparkSession

spark = SparkSession.builder.appName("load-shop").enableHiveSupport().getOrCreate()
spark.sql("create database if not exists shop")
for t in ["customers", "products", "orders", "order_items"]:
    df = spark.read.csv(f"file:///home/student/data/shop/{t}.csv", header=True, inferSchema=True)
    df.write.mode("overwrite").format("parquet").saveAsTable(f"shop.{t}")
    print("LOADED", t, df.count())
spark.stop()
