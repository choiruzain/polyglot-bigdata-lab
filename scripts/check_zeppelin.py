#!/usr/bin/env python3
"""Create and execute a Scala/Spark/Hive/Mongo/Postgres/MySQL demonstration using Zeppelin's REST API."""
import argparse
import json
import time
import urllib.request

parser = argparse.ArgumentParser()
parser.add_argument('--url', default='http://127.0.0.1:8090')
parser.add_argument('--restart', action='store_true', help='Also restart this note interpreter and rerun all cells')
args = parser.parse_args()

def api(path, data=None, method=None):
    request = urllib.request.Request(
        args.url + '/api/' + path,
        data=None if data is None else json.dumps(data).encode(),
        headers={'Content-Type': 'application/json'},
        method=method,
    )
    with urllib.request.urlopen(request, timeout=300) as response:
        result = json.load(response)
    if result.get('status') != 'OK':
        raise RuntimeError(result)
    return result.get('body')

paragraphs = [
    {'title': 'Verify Spark and Scala', 'text': '''%spark
assert(spark.version == "4.1.3", spark.version)
assert(scala.util.Properties.versionNumberString == "2.13.17")
assert(spark.range(10).count() == 10)
val doubled = sc.parallelize(1 to 5).map(_ * 2).collect().sum
assert(doubled == 30)
println("SCALA_SPARK_OK " + spark.version)
'''},
    {'title': 'Read the Hive catalog', 'text': '''%spark
spark.sql("SHOW TABLES IN shop").show(false)
assert(spark.table("shop.orders").count() == 20000)
assert(spark.table("shop.order_items").count() == 59858)
println("HIVE_COUNTS_OK")
'''},
    {'title': 'Verify delivered-order revenue (Hive)', 'text': '''%spark
val revenue = spark.sql("""
SELECT ROUND(SUM(oi.quantity * p.price), 2) AS revenue
FROM shop.order_items oi
JOIN shop.products p ON p.id = oi.product_id
JOIN shop.orders o ON o.id = oi.order_id
WHERE o.status = 'delivered'
""").first().get(0).toString
assert(BigDecimal(revenue) == BigDecimal("19252162.85"), revenue)
println("ZEPPELIN_TOTAL " + revenue)
'''},
    {'title': 'SQL notebook cell (Hive)', 'text': '''%spark.sql
SELECT category, COUNT(*) AS products
FROM shop.products GROUP BY category ORDER BY category
'''},
    {'title': 'Read PostgreSQL via JDBC (Scala)', 'text': '''%spark
{
  val pgPassword = sys.env("POSTGRES_PASSWORD")
  val pg = spark.read.format("jdbc")
    .option("url", "jdbc:postgresql://postgres:5432/shop")
    .option("dbtable", "orders")
    .option("user", "student")
    .option("password", pgPassword)
    .load()
  val n = pg.count()
  assert(n == 20000, n)
  println("SCALA_POSTGRES_ORDERS " + n)
}
'''},
    {'title': 'Read MongoDB via the Spark connector (Scala)', 'text': '''%spark
{
  val mongoPassword = sys.env("MONGO_PASSWORD")
  val mongoUri = s"mongodb://student:${mongoPassword}@mongo:27017/?authSource=shop"
  val mg = spark.read.format("mongodb")
    .option("connection.uri", mongoUri)
    .option("database", "shop")
    .option("collection", "orders")
    .load()
  val n = mg.count()
  assert(n == 20000, n)
  println("SCALA_MONGO_ORDERS " + n)
}
'''},
    {'title': 'Federated Postgres + MySQL + Hive (Scala port of t4_jdbc.py)', 'text': '''%spark
{
  val pgPassword = sys.env("POSTGRES_PASSWORD")
  val myPassword = sys.env("MYSQL_PASSWORD")

  val orders = spark.read.format("jdbc")
    .option("url", "jdbc:postgresql://postgres:5432/shop")
    .option("dbtable", "orders")
    .option("user", "student")
    .option("password", pgPassword)
    .option("driver", "org.postgresql.Driver")
    .load()

  val customers = spark.read.format("jdbc")
    .option("url", "jdbc:mysql://mysql:3306/shop")
    .option("dbtable", "customers")
    .option("user", "student")
    .option("password", myPassword)
    .option("driver", "com.mysql.cj.jdbc.Driver")
    .load()

  orders.createOrReplaceTempView("pg_orders")
  customers.createOrReplaceTempView("my_customers")
  println("PG_ORDERS " + orders.count())
  println("MYSQL_CUSTOMERS " + customers.count())

  val rows = spark.sql("""
      SELECT c.city, ROUND(SUM(oi.quantity * p.price), 2) AS revenue
      FROM pg_orders o
      JOIN my_customers c ON c.id = o.customer_id
      JOIN shop.order_items oi ON oi.order_id = o.id
      JOIN shop.products p ON p.id = oi.product_id
      WHERE o.status = 'delivered'
      GROUP BY c.city ORDER BY c.city""").collect()
  for (r <- rows) {
    println("CITY_REVENUE " + r.get(0).toString + " " + r.get(1).toString)
  }

  val fed = rows.map(r => BigDecimal(r.get(1).toString)).sum
  val hiveTotal = spark.sql("""
      SELECT ROUND(SUM(oi.quantity * p.price), 2)
      FROM shop.order_items oi
      JOIN shop.products p ON p.id = oi.product_id
      JOIN shop.orders o ON o.id = oi.order_id
      WHERE o.status = 'delivered'""").first().get(0).toString
  assert(fed == BigDecimal(hiveTotal), s"$fed != $hiveTotal")
  println("TOTAL_FEDERATED " + fed)
  println("TOTAL_HIVE_ONLY " + hiveTotal)
}
'''},
    {'title': 'MongoDB + Hive (Scala port of t5_mongo.py)', 'text': '''%spark
{
  val mongoPassword = sys.env("MONGO_PASSWORD")
  val mongoUri = s"mongodb://student:${mongoPassword}@mongo:27017/?authSource=shop"

  val orders = spark.read.format("mongodb")
    .option("connection.uri", mongoUri).option("database", "shop").option("collection", "orders").load()
  val products = spark.read.format("mongodb")
    .option("connection.uri", mongoUri).option("database", "shop").option("collection", "products").load()
  orders.createOrReplaceTempView("mg_orders")
  products.createOrReplaceTempView("mg_products")
  println("MONGO_ORDERS " + orders.count())
  println("MONGO_PRODUCTS " + products.count())

  val flat = "(SELECT status, explode(items) AS it FROM mg_orders WHERE status = 'delivered') o"
  val rows = spark.sql(s"""
      SELECT p.category, ROUND(SUM(o.it.quantity * p.price), 2) AS revenue
      FROM $flat JOIN mg_products p ON p.`_id` = o.it.product_id
      GROUP BY p.category ORDER BY p.category""").collect()
  for (r <- rows) {
    println("CATEGORY " + r.get(0).toString + " " + r.get(1).toString)
  }

  val a = spark.sql(s"""SELECT ROUND(SUM(o.it.quantity * p.price), 2)
      FROM $flat JOIN mg_products p ON p.`_id` = o.it.product_id""").first().get(0).toString
  val b = spark.sql(s"""SELECT ROUND(SUM(o.it.quantity * p.price), 2)
      FROM $flat JOIN shop.products p ON p.id = o.it.product_id""").first().get(0).toString
  assert(BigDecimal(a) == BigDecimal(b), s"$a != $b")
  println("TOTAL_MONGO_ONLY " + a)
  println("TOTAL_MONGO_PLUS_HIVE " + b)
}
'''},
]
note_id = api('notebook', {
    'notePath': '/Polyglot/Scala Spark 4.1.3 verification ' + str(int(time.time())),
    'defaultInterpreterGroup': 'spark',
    'addingEmptyParagraph': False,
    'paragraphs': paragraphs,
})
print('NOTE', args.url + '/#/notebook/' + note_id, flush=True)
note = api('notebook/' + note_id)
def run_cells():
    for paragraph in note['paragraphs']:
        result = api('notebook/run/' + note_id + '/' + paragraph['id'], {})
        if result.get('code') != 'SUCCESS':
            raise RuntimeError(json.dumps(result))
        print('PASS', paragraph['title'], json.dumps(result), flush=True)

run_cells()
if args.restart:
    setting = next(s for s in api('interpreter/setting') if s['name'] == 'spark')
    api('interpreter/setting/restart/' + setting['id'], {'noteId': note_id}, 'PUT')
    run_cells()
    print('INTERPRETER_RESTART_PASSED', flush=True)
print('ZEPPELIN_CHECKS_PASSED', flush=True)
