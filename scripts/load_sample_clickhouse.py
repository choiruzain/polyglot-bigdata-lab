import csv, datetime, os, pathlib, time
from decimal import Decimal
import clickhouse_connect

DATA = pathlib.Path(os.environ.get("SHOP_DATA", "/home/student/data/shop"))

def rows(name):
    with open(DATA / f"{name}.csv", newline="") as f:
        yield from csv.DictReader(f)

def day(s):
    return datetime.date.fromisoformat(s)

client = None
for _ in range(30):
    try:
        client = clickhouse_connect.get_client(
            host=os.environ.get("CLICKHOUSE_HOST", "clickhouse"), port=8123, username="student",
            password=os.environ["CLICKHOUSE_PASSWORD"], database="shop")
        break
    except Exception:
        time.sleep(5)
if client is None:
    raise SystemExit("ClickHouse is not ready")

tables = {
    "customers": "CREATE TABLE customers (id UInt32, name String, city LowCardinality(String), signup_date Date) "
                 "ENGINE = MergeTree ORDER BY id",
    "products": "CREATE TABLE products (id UInt32, name String, category LowCardinality(String), price Decimal(8,2)) "
                "ENGINE = MergeTree ORDER BY id",
    "orders": "CREATE TABLE orders (id UInt32, customer_id UInt32, order_date Date, status LowCardinality(String)) "
              "ENGINE = MergeTree ORDER BY (order_date, id)",
    "order_items": "CREATE TABLE order_items (order_id UInt32, product_id UInt32, quantity UInt8) "
                   "ENGINE = MergeTree ORDER BY (order_id, product_id)",
}
for name, ddl in tables.items():
    client.command(f"DROP TABLE IF EXISTS {name}")
    client.command(ddl)

def load(name, columns, data):
    for i in range(0, len(data), 50000):
        client.insert(name, data[i:i + 50000], column_names=columns)
    print("CLICKHOUSE_LOADED", name, client.query(f"SELECT count() FROM {name}").result_rows[0][0])

load("customers", ["id", "name", "city", "signup_date"],
     [(int(r["id"]), r["name"], r["city"], day(r["signup_date"])) for r in rows("customers")])
load("products", ["id", "name", "category", "price"],
     [(int(r["id"]), r["name"], r["category"], Decimal(r["price"])) for r in rows("products")])
load("orders", ["id", "customer_id", "order_date", "status"],
     [(int(r["id"]), int(r["customer_id"]), day(r["order_date"]), r["status"]) for r in rows("orders")])
load("order_items", ["order_id", "product_id", "quantity"],
     [(int(r["order_id"]), int(r["product_id"]), int(r["quantity"])) for r in rows("order_items")])

FROM = """FROM order_items AS oi
JOIN products AS p ON p.id = oi.product_id
JOIN orders AS o ON o.id = oi.order_id
WHERE o.status = 'delivered'"""
for category, revenue in client.query(
        f"SELECT p.category, round(sum(oi.quantity * p.price), 2) {FROM} GROUP BY p.category ORDER BY p.category").result_rows:
    print("CATEGORY", category, revenue)
print("CLICKHOUSE_TOTAL", client.query(f"SELECT round(sum(oi.quantity * p.price), 2) {FROM}").result_rows[0][0])
