#!/usr/bin/env python3
"""Create and execute a Scala/Spark/Hive demonstration using Zeppelin's REST API."""
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
    {'title': 'Verify delivered-order revenue', 'text': '''%spark
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
    {'title': 'SQL notebook cell', 'text': '''%spark.sql
SELECT category, COUNT(*) AS products
FROM shop.products GROUP BY category ORDER BY category
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
