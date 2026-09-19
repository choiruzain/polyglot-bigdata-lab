import csv, datetime, os, pathlib
from decimal import Decimal
from cassandra.auth import PlainTextAuthProvider
from cassandra.cluster import Cluster
from cassandra.concurrent import execute_concurrent_with_args

DATA = pathlib.Path("/home/student/data/shop")

def rows(name):
    with open(DATA / f"{name}.csv", newline="") as f:
        yield from csv.DictReader(f)

def day(s):
    return datetime.date.fromisoformat(s)

cluster = Cluster(["cassandra"], auth_provider=PlainTextAuthProvider("student", os.environ["CASSANDRA_PASSWORD"]))
s = cluster.connect("shop")

for stmt in [
    "CREATE TABLE IF NOT EXISTS customers (id int PRIMARY KEY, name text, city text, signup_date date)",
    "CREATE TABLE IF NOT EXISTS products (id int PRIMARY KEY, name text, category text, price decimal)",
    "CREATE TABLE IF NOT EXISTS orders_by_customer (customer_id int, order_date date, order_id int, status text, "
    "PRIMARY KEY ((customer_id), order_date, order_id)) WITH CLUSTERING ORDER BY (order_date DESC, order_id ASC)",
    "CREATE TABLE IF NOT EXISTS order_lines_by_category (category text, status text, order_id int, product_id int, "
    "quantity int, line_total decimal, PRIMARY KEY ((category, status), order_id, product_id))",
]:
    s.execute(stmt)
for t in ["customers", "products", "orders_by_customer", "order_lines_by_category"]:
    s.execute(f"TRUNCATE {t}")

def load(name, cql, params):
    ps = s.prepare(cql)
    execute_concurrent_with_args(s, ps, params, concurrency=50, raise_on_first_error=True)
    print("CASSANDRA_LOADED", name, len(params))

customers = [(int(r["id"]), r["name"], r["city"], day(r["signup_date"])) for r in rows("customers")]
products = {int(r["id"]): (r["category"], Decimal(r["price"]), r["name"]) for r in rows("products")}
orders = {int(r["id"]): (int(r["customer_id"]), day(r["order_date"]), r["status"]) for r in rows("orders")}

load("customers", "INSERT INTO customers (id, name, city, signup_date) VALUES (?, ?, ?, ?)", customers)
load("products", "INSERT INTO products (id, name, category, price) VALUES (?, ?, ?, ?)",
     [(pid, name, cat, price) for pid, (cat, price, name) in products.items()])
load("orders_by_customer", "INSERT INTO orders_by_customer (customer_id, order_date, order_id, status) VALUES (?, ?, ?, ?)",
     [(c, d, oid, st) for oid, (c, d, st) in orders.items()])
lines = []
for r in rows("order_items"):
    oid, pid, qty = int(r["order_id"]), int(r["product_id"]), int(r["quantity"])
    cat, price, _ = products[pid]
    lines.append((cat, orders[oid][2], oid, pid, qty, price * qty))
load("order_lines_by_category",
     "INSERT INTO order_lines_by_category (category, status, order_id, product_id, quantity, line_total) VALUES (?, ?, ?, ?, ?, ?)",
     lines)

total = Decimal("0")
for cat in sorted({v[0] for v in products.values()}):
    r = s.execute("SELECT sum(line_total) FROM order_lines_by_category WHERE category = %s AND status = 'delivered'", (cat,)).one()[0]
    print("CATEGORY", cat, r)
    total += r
print("CASSANDRA_TOTAL", total)
print("CUSTOMER_1_ORDERS", s.execute("SELECT count(*) FROM orders_by_customer WHERE customer_id = 1").one()[0])
cluster.shutdown()
