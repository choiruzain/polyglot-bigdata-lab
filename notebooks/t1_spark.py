from pyspark.sql import SparkSession
spark = (SparkSession.builder.appName("t1")
         .config("spark.sql.catalogImplementation", "in-memory").getOrCreate())
print("SPARK", spark.version)
print("COUNT", spark.range(1000).count())
spark.stop()
