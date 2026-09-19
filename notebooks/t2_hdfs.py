from pyspark.sql import SparkSession
spark = (SparkSession.builder.appName("t2")
         .config("spark.sql.catalogImplementation", "in-memory").getOrCreate())
df = spark.createDataFrame([(1, "a"), (2, "b"), (3, "c")], ["id", "v"])
df.write.mode("overwrite").parquet("hdfs://namenode:8020/tmp/spark-test")
print("HDFS_ROWS", spark.read.parquet("hdfs://namenode:8020/tmp/spark-test").count())
spark.stop()
