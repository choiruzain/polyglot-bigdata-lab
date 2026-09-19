from pyspark.sql import SparkSession
spark = (SparkSession.builder.appName("resolve-hive-client")
         .config("spark.sql.catalogImplementation", "hive")
         .config("spark.sql.hive.metastore.version", "4.1.0")
         .config("spark.sql.hive.metastore.jars", "maven")
         .config("spark.hadoop.hive.metastore.uris", "thrift://127.0.0.1:1")
         .getOrCreate())
try:
    spark.sql("show databases").collect()
except Exception as e:
    print("Expected failure (no metastore at build time):", type(e).__name__)
