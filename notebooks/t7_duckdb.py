import os, pathlib, duckdb

DATA = pathlib.Path(os.environ.get("SHOP_DATA", "/home/student/data/shop"))
OUT = pathlib.Path(os.environ.get("DEMO_OUT", "/tmp"))

con = duckdb.connect()  # in-memory: DuckDB runs inside this Python process, no server
print("DUCKDB_VERSION", duckdb.__version__)

# DuckDB queries the CSV files directly; nothing is loaded first.
for t in ["customers", "orders", "order_items"]:
    con.sql(f"CREATE VIEW {t} AS SELECT * FROM read_csv('{DATA}/{t}.csv')")
# Read prices as exact decimals, not floating point.
con.sql(f"CREATE VIEW products AS SELECT * FROM read_csv('{DATA}/products.csv', types = {{'price': 'DECIMAL(8,2)'}})")

rows = con.sql("""
    SELECT p.category, SUM(oi.quantity * p.price) AS revenue
    FROM order_items oi
    JOIN products p ON p.id = oi.product_id
    JOIN orders o ON o.id = oi.order_id
    WHERE o.status = 'delivered'
    GROUP BY p.category ORDER BY p.category""").fetchall()
for category, revenue in rows:
    print("CATEGORY", category, revenue)
print("DUCKDB_TOTAL", sum(r[1] for r in rows))

# Columnar file formats: the same table as CSV and as Parquet.
parquet = OUT / "order_items.parquet"
con.sql(f"COPY (SELECT * FROM order_items) TO '{parquet}' (FORMAT parquet)")
print("CSV_BYTES", (DATA / "order_items.csv").stat().st_size)
print("PARQUET_BYTES", parquet.stat().st_size)
print("PARQUET_ROWS", con.sql(f"SELECT count(*) FROM read_parquet('{parquet}')").fetchone()[0])
