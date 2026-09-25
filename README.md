# Polyglot Big Data Lab

**Nine engines. One dataset. One number: 19,252,162.85.**

A Docker lab for teaching big data. It runs Hadoop (HDFS), Hive, Spark and Trino, plus PostgreSQL, MySQL, MongoDB, Cassandra, Neo4j, ClickHouse and DuckDB. Every engine is loaded with the same small online-shop dataset, and every engine answers the same revenue question with the same total, so you can compare how each one works.

## Quick start (from scratch)

Everything below is meant to be copy-pasted as-is, in order.

### 1. Check prerequisites

```
docker --version
docker compose version
```

### 2. Reset to a clean baseline *(skip if you're brand new)*

Only for re-running a fresh-clone test on a machine that's had the platform before -- a first-time user has nothing to reset and should go straight to step 3.

```
cd <your-path-folder>/polyglot-bigdata-lab && docker compose down -v
cd <your-path-folder> && rm -rf polyglot-bigdata-lab
```

### 3. Fresh clone

```
git clone https://github.com/choiruzain/polyglot-bigdata-lab.git
cd polyglot-bigdata-lab
```

### 4. Start without Cassandra (the default)

```
sh scripts/platform.sh up
```

This builds the images, writes a `.env` with generated passwords (never share or commit it), and starts every module **except Cassandra** -- left out of the default profile because its password sync isn't reliable yet (harmless, self-heals -- see step 8). First run downloads every database, so allow 30-60 minutes and a few GB depending on your connection. No manual steps needed here.

### 5. Load every engine's data

```
sh scripts/load-all.sh
```

(Not `sh scripts/platform.sh load-all` -- that just prints usage text, since `load-all` isn't one of `platform.sh`'s subcommands.) You should see each engine load in turn, and a line like:

```
== Cassandra: skipped (cassandra is not running) ==
```

That's expected -- Cassandra isn't running yet.

**If you also see a port error like this, ignore it too -- it's expected:**

```
Error response from daemon: ports are not available: exposing port TCP 127.0.0.1:5432 -> 127.0.0.1:0: listen tcp4 127.0.0.1:5432: bind: address already in use
```

Port 5432 (Postgres' default) was already taken by something else on your machine -- probably another Postgres, or a leftover container from an earlier test. `platform.sh up` detects that automatically, moves the affected service to the next free port (e.g. `POSTGRES_PORT=5433`) in your `.env`, and retries. The same self-healing applies to any other port collision it reports.

### 6. Verify everything

```
sh scripts/verify-all.sh
```

Every check for a running engine passes; the Cassandra check and the Trino federated check (which needs Cassandra too) print `skipped` instead of failing, since neither can run without Cassandra.

### 7. Open JupyterLab

Open the address `platform.sh up` printed, normally <http://127.0.0.1:8888>. Run `01_hello_spark.ipynb` to confirm PySpark reads Hive. At this point you have a fully working platform with everything except Cassandra -- no manual per-engine steps were needed. (Step 11 below has the full set of example notebooks once you're here.)

### 8. Choose your modules / add Cassandra back

| Module | Adds |
|---|---|
| `bigdata-lite` (always on) | HDFS, Hive, JupyterLab |
| `sql` | PostgreSQL, MySQL |
| `mongo` | MongoDB |
| `cassandra` | Cassandra (off by default -- see step 4) |
| `neo4j` | Neo4j |
| `clickhouse` | ClickHouse |
| `trino` | SQL across every database above |

To turn a module on or off -- including adding Cassandra -- edit `COMPOSE_PROFILES` in `.env`. Two ways to do that:

**Nano**, if you're not comfortable editing files on the command line:

```
nano .env
```

Find the `COMPOSE_PROFILES=` line, edit the list of modules, then save and exit: `Ctrl+O`, `Enter`, `Ctrl+X`.

**One command**, to add Cassandra back specifically:

```
grep COMPOSE_PROFILES .env
sed -i.bak 's/^COMPOSE_PROFILES=.*/COMPOSE_PROFILES=bigdata-lite,sql,mongo,cassandra,neo4j,clickhouse,trino/' .env
rm .env.bak
```

`grep` shows you the current line before you change it; `sed -i.bak '...' .env` replaces it with the new list, keeping a backup (`.env.bak`) first in case something goes wrong; `rm .env.bak` removes that backup once you've confirmed it worked. For a lighter subset instead, edit the same line by hand, e.g. `COMPOSE_PROFILES=bigdata-lite,mongo` runs just Hive and MongoDB.

Either way you end up with a line like:

```
COMPOSE_PROFILES=bigdata-lite,sql,mongo,cassandra,neo4j,clickhouse,trino
```

Then run `sh scripts/platform.sh up` again. If you just added Cassandra, you may see:

```
sync-passwords: cassandra
  could not sync
```

**Ignore this.** It's a known, harmless race: `sync-passwords.sh` only checks that the Cassandra container is running, not that Cassandra's own `init.sh` (which creates the student login) has finished -- Cassandra self-heals a moment later once `init.sh` completes.

### 9. Confirm Cassandra actually works

```
sh scripts/platform.sh load-cassandra
docker compose exec -T tools python3 notebooks/t8_cassandra.py
```

You should see `CASSANDRA_TOTAL 19252162.85`.

### 10. Re-verify with Cassandra included

```
sh scripts/verify-all.sh
```

Now every check runs for real, including Cassandra and the Trino federated query -- no more skip lines for those two.

### 11. Using the platform day to day

- **Open JupyterLab** by clicking the address `platform.sh up` printed (normally <http://127.0.0.1:8888>).
- **Keep your own experiments out of Git:** copy any notebook into `notebooks/playground/` first -- everything in that folder is ignored by Git, so you can edit and re-run freely without it ever showing up in `git status` or a commit.
- **Try each database from Python:** `notebooks/jdbc.ipynb` (PostgreSQL + MySQL), `notebooks/mongo.ipynb`, `notebooks/neo4j.ipynb` and `notebooks/cassandra.ipynb` each connect to one engine and print its revenue total. Open, read and re-run them one at a time instead of reading the `.py` test scripts in `notebooks/` that `verify-all.sh` uses.
- **Scala:** see the [Scala](#scala) section below -- a terminal shell, a notebook that drives it (`notebooks/scala.ipynb`), or a real Scala kernel via the Zeppelin add-on.

## Scala

Jupyter here runs Python. For Scala, there are three ways to run it, depending on how interactive you want to be:

**A shell**, for quick, one-off code -- works today on `main`:

```
docker compose exec tools spark-shell
```

You get a `scala>` prompt already connected to Hive:

```scala
spark.sql("select category, count(*) as products from shop.products group by category order by category").show()
```

Type `:quit` to leave.

**From inside JupyterLab**, without opening a terminal -- `notebooks/scala.ipynb` runs on the Python kernel but its one cell drives `spark-shell` for you and prints the result back into the notebook. It's the same shell as above, just launched from a notebook cell instead of a terminal.

**A real notebook with an actual Scala kernel**, for anything more involved -- an experimental Apache Zeppelin add-on runs Scala against Spark 4.1.3, with Hive, PostgreSQL, MySQL and MongoDB all confirmed working. This lives on the `experiment-zeppelin` branch, not `main` yet:

```
git checkout experiment-zeppelin
docker compose -f compose.zeppelin.yml up -d --wait
```

Then open **http://127.0.0.1:8090**. Create a note using the `spark` interpreter and run a Scala paragraph, the same idea as the shell example above:

```scala
%spark
spark.sql("SHOW TABLES IN shop").show(false)
```

Or a SQL paragraph:

```sql
%spark.sql
SELECT category, COUNT(*) AS products
FROM shop.products GROUP BY category ORDER BY category
```

Both run through Spark against the existing Hive metastore. See [`images/zeppelin/README.md`](images/zeppelin/README.md) for the full setup and verification steps.

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
- **Testing this on a machine that has run the project before?** Deleting the project folder does not remove Docker's containers, volumes, or images -- Docker tracks those separately, keyed to the project name. `sh scripts/platform.sh reset` clears data but keeps built images (fast, seconds). For a true from-scratch rebuild -- matching exactly what a brand-new user's first run looks like -- use `bash scripts/full-rebuild.sh`, then `sh scripts/platform.sh up` again. This re-downloads and rebuilds everything, so it is slow (20-40+ minutes). Most people never need this; it exists for re-testing the platform itself.

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
notebooks/           the starter notebook, per-database example notebooks, the Scala example,
                     test scripts, and playground/ (a gitignored scratch folder)
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
- **No native Scala kernel in JupyterLab.** `notebooks/scala.ipynb` drives the `spark-shell` command from a notebook cell (see [Scala](#scala)), which covers quick one-off code; for an actual Scala kernel, use the Zeppelin add-on described in the same section.
- **Spark 4 has no Cassandra connector.** Use `cqlsh`, the Python driver, or Trino to reach Cassandra.
- **Trino has no Neo4j or Hive catalog.** Neo4j is reachable from Spark and from its own tools.
- **Teaching-grade security.** JupyterLab has no password, and there is no Kerberos: Hadoop, Hive and Trino trust the user name you give them. Every published port is bound to `127.0.0.1` and every database password is generated per machine, but do not expose this platform to a network.

## License and citation

The scripts, configuration and documentation in this repository are released under the MIT License (see [LICENSE](LICENSE)).

To cite this work, use the **"Cite this repository"** button on GitHub (reads [CITATION.cff](CITATION.cff)), or copy one of these directly:

**APA**
```
Zain, C. (2026). Polyglot Big Data Lab (Version 1.0.0) [Computer software]. https://github.com/choiruzain/polyglot-bigdata-lab
```

**BibTeX**
```bibtex
@software{Zain_Polyglot_Big_Data_Lab_2026,
  author  = {Zain, Choiru},
  license = {MIT},
  month   = sep,
  title   = {{Polyglot Big Data Lab}},
  url     = {https://github.com/choiruzain/polyglot-bigdata-lab},
  version = {1.0.0},
  year    = {2026}
}
```

## Third-party software

This repository contains scripts and configuration only. Hadoop, Hive, Spark, Trino, PostgreSQL, MySQL, MongoDB, Cassandra, Neo4j, ClickHouse and DuckDB are downloaded at build time and keep their own licenses.
