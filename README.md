# Polyglot Big Data Lab

**Nine engines. One dataset. One number: 19,252,162.85.**

A Docker lab for teaching big data. It runs Hadoop (HDFS), Hive, Spark and Trino, plus PostgreSQL, MySQL, MongoDB, Cassandra, Neo4j, ClickHouse and DuckDB. Every engine is loaded with the same small online-shop dataset, and every engine answers the same revenue question with the same total, so you can compare how each one works.

Full step-by-step instructions, troubleshooting and the list of modules are in [docs/GUIDE.md](docs/GUIDE.md).

## Quick start

You need **Docker Desktop** (Mac, Windows or Linux). On Windows, turn on WSL 2 and run every command in the **Ubuntu (WSL)** terminal. Check that Docker works:

```
docker --version
docker compose version
```

### Option 1: Notebook only (one container, about 2 GB of memory)

JupyterLab with PySpark, Scala (sbt), DuckDB and the Python database drivers. No database servers.

Once, to get the project and build the image (this takes a while and downloads several GB):

```
git clone https://github.com/choiruzain/polyglot-bigdata-lab.git
cd polyglot-bigdata-lab
docker build -t polyglot-bigdata-lab images/tools
```

1. Create a Docker network:

```
docker network create polyglot-bigdata-lab
```

2. Run the container. Change **`<YOUR-LOCAL-FOLDER>`** to the folder on your computer that holds your notebooks:

```
docker run --rm --network polyglot-bigdata-lab -v <YOUR-LOCAL-FOLDER>:/home/student/notebooks -p 8888:8888 -p 4040:4040 polyglot-bigdata-lab
```

3. Open <http://localhost:8888> and enter the password `student`.

Press `Ctrl+C` to stop. Your notebooks stay in your folder.

### Option 2: Full platform (Hadoop, Hive, Spark and the databases)

```
git clone https://github.com/choiruzain/polyglot-bigdata-lab.git
cd polyglot-bigdata-lab
sh scripts/platform.sh up
```

The first start builds the images and takes a long time. It creates a `.env` file with random passwords. Never share or commit `.env`.

Find your JupyterLab address and token, then open `http://127.0.0.1:PORT/lab?token=TOKEN`:

```
grep -E '^JUPYTER_(PORT|TOKEN)=' .env
```

Choose which modules run by editing `COMPOSE_PROFILES` in `.env`, then run `sh scripts/platform.sh up` again. Load the sample data for the modules you switched on:

```
sh scripts/platform.sh load-sample       # Hive
sh scripts/platform.sh load-sql          # PostgreSQL and MySQL
sh scripts/platform.sh load-mongo        # MongoDB
sh scripts/platform.sh load-cassandra    # Cassandra
sh scripts/platform.sh load-neo4j        # Neo4j
sh scripts/platform.sh load-clickhouse   # ClickHouse
sh scripts/platform.sh demo-duckdb       # DuckDB
```

Stop, restart and erase:

```
docker compose stop              # stops everything, keeps your data
sh scripts/platform.sh up        # starts it again
sh scripts/platform.sh reset     # ERASES all data (asks you to type yes)
```

## What is inside

| Module (`COMPOSE_PROFILES`) | What it starts | Memory when idle |
|---|---|---|
| `bigdata-lite` | HDFS, Hive (metastore and HiveServer2), the notebook container | about 1.8 GB |
| `sql` | PostgreSQL 18, MySQL 9.7 | about 0.5 GB |
| `mongo` | MongoDB 8.3 | about 0.3 GB |
| `cassandra` | Cassandra 5.0 | about 1.4 GB |
| `neo4j` | Neo4j 2026.07 (Community) | about 1 GB |
| `clickhouse` | ClickHouse 26.8 | about 0.5 GB |
| `trino` | Trino 483: SQL across the databases | about 1.1 GB |
| `tools` | the notebook container only (Spark, Scala, DuckDB) | about 0.1 GB |

Everything at once uses about 6.6 GB idle, and a Spark session adds about 1.25 GB. Measured with Docker Desktop on Apple Silicon.

The notebook container has Spark 4.1 (Scala 2.13), Python, sbt, DuckDB and command-line clients for every database. HDFS is Hadoop 3.5.0 and Hive is 4.2.1.

## The shared dataset

A small online shop, generated with a fixed random seed so everyone gets identical data: 1,000 customers, 100 products, 20,000 orders and 59,858 order lines. The question every engine answers: *what is the revenue from delivered orders?* The answer is **19252162.85**, and the loaders print it so you can check.

## Repository layout

```
docker-compose.yml   the whole platform
.env.example         settings template (copied to .env on first start)
images/              Dockerfiles: hadoop, hive, tools (with pinned Python packages)
config/              Hadoop, Hive, Tez, Spark, ClickHouse and Trino settings
scripts/             platform.sh (start, stop, load, reset) and the data loaders
notebooks/           example notebooks and test scripts
data/                sample data is generated here (not committed)
docs/                GUIDE.md
```

## Checks you can run

Three tools live in `scripts/`. Anyone can run them:

```
sh scripts/check_env.sh            # every setting and script the platform needs is in the repository
bash scripts/clean_clone_test.sh   # clones the committed repo, starts it, loads every engine, checks the totals
sh scripts/mem.sh                  # total memory used by the running containers
```

Run the clean-clone test after any change you plan to share. It refuses to run with uncommitted changes or while your own platform is running.

## Known limitations

- **Tested on Apple Silicon (ARM64) with Docker Desktop only.** Intel and AMD machines and Windows with WSL 2 have not been tested yet.
- **No YARN.** Hadoop here means HDFS; Spark runs in local mode inside the notebook container, and Hive runs its queries on Tez in local mode.
- **Spark 4 has no Cassandra connector.** Use `cqlsh`, the Python driver, or Trino to reach Cassandra.
- **Trino has no Neo4j or Hive catalog.** Neo4j is reachable from Spark and from its own tools.
- **Teaching-grade security.** There is no Kerberos, and Hadoop, Hive and Trino trust the user name you give them. Every published port is bound to `127.0.0.1` and every password is generated per machine, but do not expose this platform to a network.

## Third-party software

This repository contains scripts and configuration only. Hadoop, Hive, Spark, Trino, PostgreSQL, MySQL, MongoDB, Cassandra, Neo4j, ClickHouse and DuckDB are downloaded at build time and keep their own licenses.
