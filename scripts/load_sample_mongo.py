import csv, datetime, os, pathlib
from collections import defaultdict
from bson.decimal128 import Decimal128
from pymongo import MongoClient

DATA = pathlib.Path("/home/student/data/shop")

def rows(name):
    with open(DATA / f"{name}.csv", newline="") as f:
        yield from csv.DictReader(f)

def day(s):
    return datetime.datetime.strptime(s, "%Y-%m-%d")

client = MongoClient(host="mongo", username="student", password=os.environ["MONGO_PASSWORD"],
                     authSource="shop")
db = client["shop"]
for c in ["customers", "products", "orders"]:
    db[c].drop()

db.customers.insert_many([{"_id": int(r["id"]), "name": r["name"], "city": r["city"],
                           "signup_date": day(r["signup_date"])} for r in rows("customers")])
db.products.insert_many([{"_id": int(r["id"]), "name": r["name"], "category": r["category"],
                          "price": Decimal128(r["price"])} for r in rows("products")])

items = defaultdict(list)
for r in rows("order_items"):
    items[int(r["order_id"])].append({"product_id": int(r["product_id"]), "quantity": int(r["quantity"])})
orders = [{"_id": int(r["id"]), "customer_id": int(r["customer_id"]),
           "order_date": day(r["order_date"]), "status": r["status"],
           "items": items[int(r["id"])]} for r in rows("orders")]
for i in range(0, len(orders), 5000):
    db.orders.insert_many(orders[i:i + 5000])
db.orders.create_index("customer_id")
db.orders.create_index("status")

print("MONGO_LOADED customers", db.customers.count_documents({}))
print("MONGO_LOADED products", db.products.count_documents({}))
print("MONGO_LOADED orders", db.orders.count_documents({}))
print("MONGO_LOADED items", sum(len(o["items"]) for o in orders))
