import os
from cassandra.auth import PlainTextAuthProvider
from cassandra.cluster import Cluster

auth = PlainTextAuthProvider(username="student", password=os.environ["CASSANDRA_PASSWORD"])
cluster = Cluster(["cassandra"], port=9042, auth_provider=auth)
session = cluster.connect("shop")

categories = ["Books", "Electronics", "Garden", "Home", "Sports", "Toys"]
total = 0.0
for cat in categories:
    row = session.execute(
        "SELECT sum(line_total) AS revenue FROM order_lines_by_category WHERE category = %s AND status = 'delivered'",
        (cat,),
    ).one()
    revenue = float(row.revenue) if row and row.revenue is not None else 0.0
    total += revenue
    print("CATEGORY", cat, round(revenue, 2))

print("CASSANDRA_TOTAL", round(total, 2))
cluster.shutdown()
