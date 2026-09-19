import csv, datetime, pathlib, random, sys

out = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "data/shop")
out.mkdir(parents=True, exist_ok=True)
rng = random.Random(42)  # fixed seed: every student gets identical data

first = ["Alice", "Bob", "Carol", "Dave", "Eve", "Frank", "Grace", "Heidi", "Ivan", "Judy",
         "Ken", "Lena", "Mo", "Nina", "Omar", "Priya", "Quinn", "Rosa", "Sam", "Tina"]
last = ["Adams", "Baker", "Chen", "Diaz", "Evans", "Fischer", "Gupta", "Hughes", "Ito", "Jones",
        "Khan", "Lopez", "Moreau", "Nguyen", "Okafor", "Petrov", "Quist", "Rossi", "Silva", "Tanaka"]
cities = ["London", "Paris", "Tokyo", "Nairobi", "Lima", "Toronto", "Sydney", "Mumbai"]
categories = ["Books", "Electronics", "Home", "Sports", "Toys", "Garden"]
statuses = ["delivered", "shipped", "cancelled", "returned"]
weights = [70, 15, 10, 5]
start = datetime.date(2024, 1, 1)

def rand_date():
    return (start + datetime.timedelta(days=rng.randrange(730))).isoformat()

def write(name, header, rows):
    with open(out / f"{name}.csv", "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(rows)

customers = [(i, f"{rng.choice(first)} {rng.choice(last)}", rng.choice(cities), rand_date())
             for i in range(1, 1001)]
products = []
for i in range(1, 101):
    cat = rng.choice(categories)
    products.append((i, f"{cat} item {i}", cat, round(rng.uniform(3, 400), 2)))
orders, items = [], []
for oid in range(1, 20001):
    orders.append((oid, rng.randint(1, 1000), rand_date(), rng.choices(statuses, weights)[0]))
    for pid in rng.sample(range(1, 101), rng.randint(1, 5)):
        items.append((oid, pid, rng.randint(1, 4)))

write("customers", ["id", "name", "city", "signup_date"], customers)
write("products", ["id", "name", "category", "price"], products)
write("orders", ["id", "customer_id", "order_date", "status"], orders)
write("order_items", ["order_id", "product_id", "quantity"], items)
print("WROTE", {"customers": len(customers), "products": len(products),
                "orders": len(orders), "order_items": len(items)})
