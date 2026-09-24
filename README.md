# Polyglot Big Data Lab

**Nine engines. One dataset. One number: 19,252,162.85.**

A Docker lab for teaching big data. It runs Hadoop (HDFS), Hive, Spark and Trino, plus PostgreSQL, MySQL, MongoDB, Cassandra, Neo4j, ClickHouse and DuckDB. Every engine is loaded with the same small online-shop dataset, and every engine answers the same revenue question with the same total, so you can compare how each one works.

## Quick start (from scratch)

Everything below is meant to be copy-pasted as-is. No manual steps in between.

```
docker --version
docker compose version
```

```
git clone https://github.com/choiruzain/polyglot-bigdata-lab.git
cd polyglot-bigdata-lab
```

**Start everything, then load every engine's data, in two commands:**

```
sh scripts/platform.sh up
sh scripts/platform.sh load-all
```

The first `up` builds every image and downloads every database on first run -- allow 30-60 minutes and a few GB, depending on your connection. `.env` is created automatically with random passwords; never share or commit it. `load-all` loads the shared shop dataset into whichever engines are actually running, skipping the rest -- no need to run each loader by hand.

Open **http://127.0.0.1:8888** for JupyterLab (no password -- see [Known limitations](#known-limitations)). Run `01_hello_spark.ipynb` for a first PySpark example against Hive.

**Check every engine at once**, and see the same total (`19252162.85`) from each:

```
sh scripts/verify-all.sh
```

That runs the Hive+PostgreSQL+MySQL join, the MongoDB example, Neo4j, Cassandra, and the Trino federated query in sequence, skipping any engine that isn't currently running.

## Choose your modules (optional)

By default every module is on, so the commands above show the whole platform. To run a lighter subset instead, edit `COMPOSE_PROFILES` in `.env`, then run `sh scripts/platform.sh up` again:

| Module | Adds |
|---|---|
| `bigdata-lite` (always on) | HDFS, Hive, JupyterLab |
| `sql` | PostgreSQL, MySQL |
| `mongo` | MongoDB |
| `cassandra` | Cassandra |
| `neo4j` | Neo4j |
| `clickhouse` | ClickHouse |
| `trino` | SQL across every database above |

Example: `COMPOSE_PROFILES=bigdata-lite,mongo` runs just Hive and MongoDB.

## Scala

Jupyter here runs Python. For Scala, there are two ways to run it, depending on how interactive you want to be:

**A shell**, for quick, one-off code -- works today on `main`:

```
docker compose exec tools spark-shell
```

You get a `scala>` prompt already connected to Hive:
```scala
spark.sql("select category, count(*) as products from shop.products group by category order by category").show()
```
Type `:quit` to leave.

**A real notebook**, for anything more involved -- an experimental Apache Zeppelin add-on runs Scala against Spark 4.1.3, with Hive, PostgreSQL, MySQL and MongoDB all confirmed working. This lives on the `experiment-zeppelin` branch, not `main` yet:

```
git checkout experiment-zeppelin
docker compose -f compose.zeppelin.yml up -d --wait
```

Then open **http://127.0.0.1:8090**. See [`images/zeppelin/README.md`](images/zeppelin/README.md) for the full setup and verification steps.

## Stop, restart, erase

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
