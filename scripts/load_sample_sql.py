import csv, os, pathlib
import mysql.connector
import psycopg

DATA = pathlib.Path("/home/student/data/shop")
SQL = pathlib.Path("/home/student/scripts/sql")
TABLES = ["customers", "products", "orders", "order_items"]

def statements(path):
    return [s.strip() for s in path.read_text().split(";") if s.strip()]

def load_postgres():
    with psycopg.connect(host="postgres", dbname="shop", user="student",
                         password=os.environ["POSTGRES_PASSWORD"]) as conn:
        with conn.cursor() as cur:
            for s in statements(SQL / "postgres_schema.sql"):
                cur.execute(s)
            for t in TABLES:
                with cur.copy(f"COPY {t} FROM STDIN WITH (FORMAT csv, HEADER true)") as copy:
                    copy.write((DATA / f"{t}.csv").read_bytes())
                cur.execute(f"SELECT count(*) FROM {t}")
                print("PG_LOADED", t, cur.fetchone()[0])

def load_mysql():
    conn = mysql.connector.connect(host="mysql", database="shop", user="student",
                                   password=os.environ["MYSQL_PASSWORD"])
    cur = conn.cursor()
    for s in statements(SQL / "mysql_schema.sql"):
        cur.execute(s)
    for t in TABLES:
        with open(DATA / f"{t}.csv", newline="") as f:
            reader = csv.reader(f)
            header = next(reader)
            sql = f"INSERT INTO {t} ({','.join(header)}) VALUES ({','.join(['%s'] * len(header))})"
            batch = []
            for row in reader:
                batch.append(row)
                if len(batch) == 5000:
                    cur.executemany(sql, batch)
                    batch = []
            if batch:
                cur.executemany(sql, batch)
        cur.execute(f"SELECT count(*) FROM {t}")
        print("MY_LOADED", t, cur.fetchone()[0])
    conn.commit()
    cur.close()
    conn.close()

if __name__ == "__main__":
    load_postgres()
    load_mysql()
