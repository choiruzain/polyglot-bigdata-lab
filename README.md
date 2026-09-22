# Polyglot Big Data Lab

**Nine engines. One dataset. One number: 19,252,162.85.**

A Docker lab for teaching big data. It runs Hadoop (HDFS), Hive, Spark and Trino, plus PostgreSQL, MySQL, MongoDB, Cassandra, Neo4j, ClickHouse and DuckDB. Every engine is loaded with the same small online-shop dataset, and every engine answers the same revenue question with the same total, so you can compare how each one works.

## Quick start

You need **Docker Desktop** (Mac, Windows or Linux). On Windows, turn on WSL 2, run every command in the **Ubuntu (WSL)** terminal, and keep the project inside the WSL file system. Give Docker enough memory (Docker Desktop, Settings, Resources): the default start needs about 3 GB while Spark runs, and every module together needs about 8 GB, so 12 GB is comfortable. Check that Docker works:

```
docker --version
docker compose version
```

### 1. Get the project

```
git clone https://github.com/choiruzain/polyglot-bigdata-lab.git
cd polyglot-bigdata-lab
```

### 2. Start the platform

```
sh scripts/platform.sh up
```

The first start builds the images and downloads a few GB. It took about 40 minutes with every module on a fast connection, and later starts take a minute or two. It creates a `.env` file with random passwords for the databases. Never share or commit `.env`. When it finishes, it prints the address of JupyterLab.

### 3. Open JupyterLab

Open the address it printed, normally <http://127.0.0.1:8888>. There is no password, because the platform only listens on your own computer. Do not change `BIND_ADDRESS` in `.env` to publish it on a network: without a password, anyone who could reach it could run code on your computer.

### 4. Load the sample data

```
sh scripts/platform.sh load-sample
```

This loads the shop dataset into Hive. Python and Scala both read it through the same Hive metastore.

### 5. Choose Python or Scala

**Python (a notebook).** In JupyterLab, open `01_hello_spark.ipynb` and press Shift+Enter on its cell. It lists the shop tables and counts the products in each category, using PySpark.

**Scala (a shell).** Scala does not run inside a notebook here. It has its own shell. In JupyterLab choose **File, New, Terminal**, then type:

```
spark-shell
```

After a short start-up you get a `scala>` prompt. `spark` is already connected to Hive, so you can type:

```
spark.sql("show tables in shop").show()
spark.sql("select category, count(*) as products from shop.products group by category order by category").show()
```

Type `:quit` to leave. To build a Scala project instead of typing in a shell, see step 7.

### 6. Load and try the other engines

The default start runs HDFS, Hive and JupyterLab. To add databases, open `.env`, change the `COMPOSE_PROFILES` line, and run `sh scripts/platform.sh up` again. For example, `COMPOSE_PROFILES=bigdata-lite,sql,mongo` adds PostgreSQL, MySQL and MongoDB. Load the data for each module you switched on:

| Module | Load the shop data | You should see |
|---|---|---|
| Hive (default) | `sh scripts/platform.sh load-sample` | `LOADED order_items 59858` |
| `sql` | `sh scripts/platform.sh load-sql` | `PG_LOADED order_items 59858` and `MY_LOADED order_items 59858` |
| `mongo` | `sh scripts/platform.sh load-mongo` | `MONGO_LOADED items 59858` |
| `cassandra` | `sh scripts/platform.sh load-cassandra` | `CASSANDRA_TOTAL 19252162.85` |
| `neo4j` | `sh scripts/platform.sh load-neo4j` | `NEO4J_TOTAL 19252162.85` |
| `clickhouse` | `sh scripts/platform.sh load-clickhouse` | `CLICKHOUSE_TOTAL 19252162.85` |
| DuckDB (no server) | `sh scripts/platform.sh demo-duckdb` | `DUCKDB_TOTAL 19252162.85` |

Then use the engines together. Each command names the modules it needs, and prints a line ending in the same total, `19252162.85`:

```
docker compose exec -T tools spark-submit notebooks/t4_jdbc.py 2>&1 | grep TOTAL_
docker compose exec -T tools spark-submit notebooks/t5_mongo.py 2>&1 | grep TOTAL_
docker compose exec -T tools spark-submit notebooks/t6_neo4j.py 2>&1 | grep TOTAL_
docker compose exec -T tools python3 notebooks/t8_cassandra.py 2>&1 | grep TOTAL_
docker compose exec -T trino trino --output-format ALIGNED --file /scripts/federated.sql
```

The first joins Hive, PostgreSQL and MySQL in one Spark query (needs `sql`). The second reads MongoDB (needs `mongo`). The third reads Neo4j (needs `neo4j`). The fourth reads Cassandra directly, using `cassandra-driver` since Spark 4 has no Cassandra connector (needs `cassandra`). The last is one Trino SQL query across the databases, and prints the revenue per city (needs `trino`, and the databases you switched on).

### 7. Scala projects with sbt (optional)

To build a Scala project, use sbt, which is already in the notebook container. `notebooks/scala-hello` is a small job that reads the shop data from Hive, so load it first (step 4). The first compile downloads the Scala compiler, so it needs internet and takes a few minutes:

```
docker compose exec tools sh -c 'cd notebooks/scala-hello && sbt -batch package'
docker compose exec tools spark-submit --class HelloScala notebooks/scala-hello/target/scala-2.13/hello-scala_2.13-0.1.0.jar
```

Look for the `SCALA_ROWS` line: one row for each product category. Copy the folder to start a project of your own.

### 8. Stop, restart, erase

```
docker compose stop              # stops everything, keeps your data
sh scripts/platform.sh up        # starts it again
sh scripts/platform.sh reset     # ERASES all data in the platform (asks you to type yes)
```

## Notebook only (one container)

If you only want PySpark, the Scala tools and DuckDB with your own folder of notebooks, and no databases, run just the notebook container. It needs about 2 GB. Build the image once, from the project folder:

```
docker build -t polyglot-bigdata-lab images/tools
```

Then run it. Change **`<YOUR-LOCAL-FOLDER>`** to the folder on your computer that holds your notebooks (for example `$HOME/labs`, or `/mnt/c/Users/YourName/labs` in the Ubuntu WSL terminal):

```
docker run --rm -v <YOUR-LOCAL-FOLDER>:/home/student/notebooks -p 127.0.0.1:8888:8888 -p 127.0.0.1:4040:4040 polyglot-bigdata-lab
```

Open <http://127.0.0.1:8888>. While a Spark session runs, its web page is at <http://127.0.0.1:4040>. Press `Ctrl+C` to stop. Your notebooks stay in your folder, and anything saved outside it is deleted when the container stops. This container has no databases and no Hive data, so the starter notebook and the Scala example need the full platform. The `127.0.0.1` in the ports keeps it private to your computer, which matters because it has no password.

**Port 8888 already in use?** Another subject's container may be holding it, and `docker run` then stops with "port is already allocated". See what holds it:

```
docker ps --format '{{.Names}}   {{.Image}}   {{.Ports}}' | grep ':8888->'
```

Stop it if you recognise it and no longer need it (a container that was started with `--rm` is deleted when it stops):

```
docker stop $(docker ps --format '{{.ID}} {{.Ports}}' | grep ':8888->' | cut -d' ' -f1)
```

Or leave it alone and use another port: change `-p 127.0.0.1:8888:8888` to `-p 127.0.0.1:8889:8888` in the run command, and open <http://127.0.0.1:8889>. If the first command prints nothing, a program on your computer uses the port. On Mac and Linux, `lsof -nP -iTCP:8888 -sTCP:LISTEN` names it.

## What is inside

| Module (`COMPOSE_PROFILES`) | What it starts | Memory when idle |
|---|---|---|
| `bigdata-lite` (default) | HDFS, Hive (metastore and HiveServer2), the notebook container | about 1.8 GB |
| `sql` | PostgreSQL 18, MySQL 9.7 | about 0.5 GB |
| `mongo` | MongoDB 8.3 | about 0.3 GB |
| `cassandra` | Cassandra 5.0 | about 1.4 GB |
| `neo4j` | Neo4j 2026.07 (Community) | about 1 GB |
| `clickhouse` | ClickHouse 26.8 | about 0.5 GB |
| `trino` | Trino 483: SQL across the databases | about 1.1 GB |
| `tools` | the notebook container only (Spark, Scala, DuckDB) | about 0.1 GB |

Everything at once uses about 6 GB idle, and a Spark session adds about 1.25 GB. Measured with Docker Desktop on Apple Silicon. The notebook container has Spark 4.1 (Scala 2.13), Python, sbt, DuckDB and command-line clients for the databases. HDFS is Hadoop 3.5.0 and Hive is 4.2.1.

## The shared dataset

A small online shop, generated with a fixed random seed so everyone gets identical data: 1,000 customers, 100 products, 20,000 orders and 59,858 order lines. The question every engine answers: *what is the revenue from delivered orders?* The answer is **19252162.85**, and the loaders print it so you can check.

## If something goes wrong

- **The browser says "refused to connect":** nothing is running. Run `sh scripts/platform.sh up` and open the address it prints. If port 8888 was busy, the start moves JupyterLab to the next free port and the address shows the new one.
- **"port is already allocated":** `sh scripts/platform.sh up` moves a busy port to the next free one by itself and says which. If it says a port is not set in `.env`, add a line for it, for example `NAMENODE_UI_PORT=9871`. For the notebook-only container, see the port section above.
- **After restarting your computer or Docker, things fail with "unknown host" or a service is missing:** containers do not restart by themselves. Run `sh scripts/platform.sh up`.
- **A start says a container is not healthy:** slow computers can take a while. The start waits a few more minutes, and if the container is still not healthy it prints that container's log. Run `sh scripts/platform.sh up` again.
- **A container disappears, or things become very slow:** you are probably out of memory. Switch off modules you do not need, or give Docker more memory.
- **Cassandra and Neo4j are slow to start.** Wait for `sh scripts/platform.sh up` to finish before you load data.
- **You changed a password in `.env` after the first start,** and a database now refuses you: the database kept its original password. Run `sh scripts/platform.sh reset`, then start again.
- **Testing this on a machine that has run the project before?** Deleting the project folder does not remove Docker's containers, volumes, or images — Docker tracks those separately, keyed to the project name. `sh scripts/platform.sh reset` clears data but keeps built images (fast, seconds). For a true from-scratch rebuild — matching exactly what a brand-new user's first run looks like — use `bash scripts/full-rebuild.sh`, then `sh scripts/platform.sh up` again. This re-downloads and rebuilds everything, so it is slow (20-40+ minutes). Most people never need this; it exists for re-testing the platform itself.

## Tips

Run a one-off Hive query from the command line. Beeline may print harmless logging warnings before the result:

```
docker compose exec -T hiveserver2 beeline -u jdbc:hive2://localhost:10000 -n student -e "select count(*) from shop.orders"
```

For an interactive session, use Spark SQL in JupyterLab instead. The interactive beeline prompt draws its tables staggered on some terminals. To use your own folder of notebooks with the full platform, add `NOTEBOOKS_DIR=/full/path/to/your/labs` to `.env` and run `sh scripts/platform.sh up`.

## Repository layout

```
docker-compose.yml   the whole platform
.env.example         settings template (copied to .env on first start)
images/              Dockerfiles: hadoop, hive, tools (with pinned Python packages)
config/              Hadoop, Hive, Tez, Spark, ClickHouse and Trino settings
scripts/             platform.sh (start, stop, load, reset), the data loaders and the checks
notebooks/           the starter notebook, the Scala example and test scripts
data/                sample data is generated here (not committed)
LICENSE, CITATION.cff
```

## Checks you can run

Four tools live in `scripts/`. Anyone can run them:

```
sh scripts/check_env.sh            # every setting and script the platform needs is in the repository
bash scripts/clean_clone_test.sh   # clones the committed repo, starts it, loads every engine, checks the totals
sh scripts/mem.sh                  # total memory used by the running containers
sh scripts/pin_bases.sh            # pin (or refresh) the Java base images by digest
```

Run the clean-clone test after any change you plan to share. It refuses to run with uncommitted changes or while your own platform is running.

## Known limitations

- **Tested on Apple Silicon (ARM64) with Docker Desktop only.** Intel and AMD machines and Windows with WSL 2 have not been tested yet.
- **No YARN.** Hadoop here means HDFS; Spark runs in local mode inside the notebook container, and Hive runs its queries on Tez in local mode.
- **No Scala notebook.** Scala runs in a separate shell (step 5) or as a compiled job (step 7).
- **Spark 4 has no Cassandra connector.** Use `cqlsh`, the Python driver, or Trino to reach Cassandra.
- **Trino has no Neo4j or Hive catalog.** Neo4j is reachable from Spark and from its own tools.
- **Teaching-grade security.** JupyterLab has no password, and there is no Kerberos: Hadoop, Hive and Trino trust the user name you give them. Every published port is bound to `127.0.0.1` and every database password is generated per machine, but do not expose this platform to a network.

## License and citation

The scripts, configuration and documentation in this repository are released under the MIT License (see [LICENSE](LICENSE)). To cite this work, use the "Cite this repository" button on GitHub, which reads [CITATION.cff](CITATION.cff).

## Third-party software

This repository contains scripts and configuration only. Hadoop, Hive, Spark, Trino, PostgreSQL, MySQL, MongoDB, Cassandra, Neo4j, ClickHouse and DuckDB are downloaded at build time and keep their own licenses.
