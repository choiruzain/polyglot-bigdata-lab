import os
from pyspark.sql import SparkSession, functions as F

pw = os.environ["NEO4J_PASSWORD"]
spark = SparkSession.builder.appName("t6-neo4j").enableHiveSupport().getOrCreate()

def neo(**extra):
    r = (spark.read.format("org.neo4j.spark.DataSource")
         .option("url", "bolt://neo4j:7687")
         .option("authentication.basic.username", "neo4j")
         .option("authentication.basic.password", pw))
    for k, v in extra.items():
        r = r.option(k, v)
    return r.load()

print("NEO4J_CUSTOMERS", neo(labels=":Customer").count())

lines = neo(query="MATCH (o:Order {status: 'delivered'})-[c:CONTAINS]->(p:Product)-[:IN_CATEGORY]->(cat:Category) "
                  "RETURN cat.name AS category, c.quantity AS quantity, p.price_cents AS price_cents")
rows = (lines.groupBy("category")
        .agg(F.sum(F.col("quantity") * F.col("price_cents")).alias("cents"))
        .orderBy("category").collect())
fmt = lambda c: f"{int(c) // 100}.{int(c) % 100:02d}"
for r in rows:
    print("CATEGORY", r["category"], fmt(r["cents"]))
print("TOTAL_NEO4J_SPARK", fmt(sum(int(r["cents"]) for r in rows)))

hive = spark.sql("""SELECT ROUND(SUM(oi.quantity * p.price), 2)
    FROM shop.order_items oi JOIN shop.products p ON p.id = oi.product_id
    JOIN shop.orders o ON o.id = oi.order_id WHERE o.status = 'delivered'""").first()[0]
print("TOTAL_HIVE", hive)
jvm = spark.sparkContext._jvm
spark.stop()
jvm.System.exit(0)  # the Neo4j driver leaves non-daemon threads that keep the JVM alive
