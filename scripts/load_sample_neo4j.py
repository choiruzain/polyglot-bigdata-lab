import csv, os, pathlib, time
from decimal import Decimal
from neo4j import GraphDatabase

DATA = pathlib.Path("/home/student/data/shop")

def rows(name):
    with open(DATA / f"{name}.csv", newline="") as f:
        yield from csv.DictReader(f)

def batches(items, n=5000):
    for i in range(0, len(items), n):
        yield items[i:i + n]

driver = GraphDatabase.driver("bolt://neo4j:7687", auth=("neo4j", os.environ["NEO4J_PASSWORD"]))
for _ in range(30):
    try:
        driver.verify_connectivity()
        break
    except Exception:
        time.sleep(5)
else:
    raise SystemExit("Neo4j is not ready")

def run(cql, **params):
    with driver.session() as s:
        s.run(cql, **params).consume()

def scalar(cql):
    with driver.session() as s:
        return s.run(cql).single()[0]

run("CALL () { MATCH (n) DETACH DELETE n } IN TRANSACTIONS OF 10000 ROWS")
for label, prop in [("Customer", "id"), ("Product", "id"), ("Order", "id"), ("Category", "name")]:
    run(f"CREATE CONSTRAINT {label.lower()}_{prop} IF NOT EXISTS FOR (n:{label}) REQUIRE n.{prop} IS UNIQUE")

customers = [{"id": int(r["id"]), "name": r["name"], "city": r["city"], "signup_date": r["signup_date"]} for r in rows("customers")]
products = [{"id": int(r["id"]), "name": r["name"], "category": r["category"],
             "price_cents": int(Decimal(r["price"]) * 100)} for r in rows("products")]
orders = [{"id": int(r["id"]), "customer_id": int(r["customer_id"]), "order_date": r["order_date"],
           "status": r["status"]} for r in rows("orders")]
items = [{"order_id": int(r["order_id"]), "product_id": int(r["product_id"]),
          "quantity": int(r["quantity"])} for r in rows("order_items")]

run("UNWIND $names AS n CREATE (:Category {name: n})", names=sorted({p["category"] for p in products}))
for b in batches(customers):
    run("UNWIND $rows AS r CREATE (:Customer {id: r.id, name: r.name, city: r.city, signup_date: date(r.signup_date)})", rows=b)
for b in batches(products):
    run("UNWIND $rows AS r MATCH (c:Category {name: r.category}) "
        "CREATE (:Product {id: r.id, name: r.name, price_cents: r.price_cents})-[:IN_CATEGORY]->(c)", rows=b)
for b in batches(orders):
    run("UNWIND $rows AS r MATCH (c:Customer {id: r.customer_id}) "
        "CREATE (c)-[:PLACED]->(:Order {id: r.id, order_date: date(r.order_date), status: r.status})", rows=b)
for b in batches(items):
    run("UNWIND $rows AS r MATCH (o:Order {id: r.order_id}), (p:Product {id: r.product_id}) "
        "CREATE (o)-[:CONTAINS {quantity: r.quantity}]->(p)", rows=b)

print("NEO4J_LOADED customers", scalar("MATCH (n:Customer) RETURN count(n)"))
print("NEO4J_LOADED products", scalar("MATCH (n:Product) RETURN count(n)"))
print("NEO4J_LOADED orders", scalar("MATCH (n:Order) RETURN count(n)"))
print("NEO4J_LOADED categories", scalar("MATCH (n:Category) RETURN count(n)"))
print("NEO4J_LOADED contains", scalar("MATCH ()-[r:CONTAINS]->() RETURN count(r)"))

fmt = lambda cents: f"{cents // 100}.{cents % 100:02d}"
total = 0
with driver.session() as s:
    for r in s.run("MATCH (o:Order {status: 'delivered'})-[c:CONTAINS]->(p:Product)-[:IN_CATEGORY]->(cat:Category) "
                   "RETURN cat.name AS category, sum(c.quantity * p.price_cents) AS cents ORDER BY category"):
        print("CATEGORY", r["category"], fmt(r["cents"]))
        total += r["cents"]
print("NEO4J_TOTAL", fmt(total))
driver.close()
