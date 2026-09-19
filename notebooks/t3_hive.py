from pyspark.sql import SparkSession
spark = SparkSession.builder.appName("t3").enableHiveSupport().getOrCreate()
print("DATABASES", [r[0] for r in spark.sql("show databases").collect()])
print("TABLES", [r.tableName for r in spark.sql("show tables").collect()])
print("ROWS", spark.sql("select * from demo order by id").collect())
spark.createDataFrame([(3, "carol"), (4, "dave")], ["id", "name"]) \
     .write.mode("overwrite").saveAsTable("spark_demo")
print("SPARK_DEMO", spark.sql("select * from spark_demo order by id").collect())
spark.stop()
