# Polyglot Big Data Lab: Guide

Two ways to work. Pick one.

| | Option 1: Notebook only | Option 2: Full platform |
|---|---|---|
| What runs | One container with JupyterLab | Hadoop, Hive, Spark and the databases, each in its own container |
| You get | PySpark, Scala (sbt), DuckDB, Python database drivers | Everything in Option 1, plus HDFS, Hive, PostgreSQL, MySQL, MongoDB, Cassandra, Neo4j, ClickHouse and Trino |
| Memory needed | about 2 GB | about 7 GB idle, up to about 11 GB when busy |
| Good for | Spark and Python labs on your own data | Labs that use HDFS, Hive or the databases |

## Before you start

1. Install **Docker Desktop** (Mac, Windows or Linux) and start it.
2. **Windows only:** turn on WSL 2 when Docker Desktop asks, and run every command below in the **Ubuntu (WSL)** terminal, not in PowerShell.
3. Check that Docker works. Both commands should print a version:

```
docker --version
docker compose version
```

4. For Option 2, give Docker enough memory: Docker Desktop, Settings, Resources, Memory: **12 GB**.

---

## Option 1: Notebook only

Step 0 (once): get the project and build the image. This takes a while the first time and downloads several GB.

```
git clone https://github.com/choiruzain/polyglot-bigdata-lab.git
cd polyglot-bigdata-lab
docker build -t polyglot-bigdata-lab images/tools
```

### 1. Create a Docker network

```
docker network create polyglot-bigdata-lab
```

If it says the network already exists, that is fine.

### 2. Run the Docker container

Change **`<YOUR-LOCAL-FOLDER>`** to the folder on your computer that contains your notebook files.

```
docker run --rm --network polyglot-bigdata-lab -v <YOUR-LOCAL-FOLDER>:/home/student/notebooks -p 8888:8888 -p 4040:4040 polyglot-bigdata-lab
```

Examples of a folder:

- Mac or Linux: `$HOME/labs`
- Windows (Ubuntu/WSL terminal): `/mnt/c/Users/YourName/labs`

### 3. Open JupyterLab

Go to <http://localhost:8888> and enter the password **`student`**.

While a Spark session is running, its web page is at <http://localhost:4040>.

### Stop

Press `Ctrl+C` in the terminal. Your notebooks stay in your local folder. Anything you saved outside `/home/student/notebooks` is deleted when the container stops.

### If port 8888 is already in use

Another subject's notebook container may be using port 8888 without you realising it. Then `docker run` stops with "port is already allocated". First see what holds the port:

```
docker ps --format '{{.Names}}   {{.Image}}   {{.Ports}}' | grep ':8888->'
```

If it lists a container you recognise and no longer need, stop it. Stopping deletes nothing, unless that container was started with `--rm`:

```
docker stop $(docker ps --format '{{.ID}} {{.Ports}}' | grep ':8888->' | cut -d' ' -f1)
```

Or leave that container alone and use a different port. In the `docker run` command, change `-p 8888:8888` to `-p 8889:8888`, then open <http://localhost:8889\> instead.

If the first command prints nothing, the port belongs to a program on your computer, not to Docker. On Mac and Linux, this names it:

```
lsof -nP -iTCP:8888 -sTCP:LISTEN
```

---

## Option 2: Full platform

### 1. Get the project (skip if you already did)

```
git clone https://github.com/choiruzain/polyglot-bigdata-lab.git
cd polyglot-bigdata-lab
```

Windows: keep the project inside the Ubuntu (WSL) file system, for example `~/polyglot-bigdata-lab`, not under `C:\`.

### 2. Start it

```
sh scripts/platform.sh up
```

The first start builds the images. It took about 40 minutes on a fast connection, and later starts take a minute or two. It also creates a file called `.env` with random passwords. Never share or commit `.env`.

### 3. Open JupyterLab

This prints your port and token:

```
grep -E '^JUPYTER_(PORT|TOKEN)=' .env
```

Open `http://127.0.0.1:PORT/lab?token=TOKEN` with those two values filled in.

### 4. Choose which modules run

Open `.env` in a text editor and change the line `COMPOSE_PROFILES`. Then run `sh scripts/platform.sh up` again.

| Module | What it starts | Memory when idle |
|---|---|---|
| `bigdata-lite` | HDFS, Hive, and the notebook container | about 1.8 GB |
| `sql` | PostgreSQL and MySQL | about 0.5 GB |
| `mongo` | MongoDB | about 0.3 GB |
| `cassandra` | Cassandra | about 1.4 GB |
| `neo4j` | Neo4j | about 1 GB |
| `clickhouse` | ClickHouse | about 0.5 GB |
| `trino` | Trino (query across the databases) | about 1.1 GB |
| `tools` | only the notebook container (use this on its own for DuckDB and Spark labs) | about 0.1 GB |

Example: `COMPOSE_PROFILES=bigdata-lite,sql,mongo`

### 5. Load the sample data

Run only the lines for the modules you switched on:

```
sh scripts/platform.sh load-sample       # Hive
sh scripts/platform.sh load-sql          # PostgreSQL and MySQL
sh scripts/platform.sh load-mongo        # MongoDB
sh scripts/platform.sh load-cassandra    # Cassandra
sh scripts/platform.sh load-neo4j        # Neo4j
sh scripts/platform.sh load-clickhouse   # ClickHouse
sh scripts/platform.sh demo-duckdb       # DuckDB (no server needed)
```

Every engine should end with the same revenue total, `19252162.85`.

### 6. Use your own notebooks folder (optional)

Add this line to `.env`, with the full path to your folder, then run `sh scripts/platform.sh up`:

```
NOTEBOOKS_DIR=/full/path/to/your/labs
```

### Stop, restart, erase

```
docker compose stop              # stops everything, keeps your data
sh scripts/platform.sh up        # starts it again
sh scripts/platform.sh reset     # ERASES all data in the platform (asks you to type yes)
```

---

## If something goes wrong

- **"port is already allocated" (Option 1):** see "If port 8888 is already in use" above.
- **"port is already allocated" (Option 2):** `sh scripts/platform.sh up` moves a busy port to the next free one by itself and says which. Run `grep -E '^JUPYTER_PORT=' .env` to see the port to open for JupyterLab. If it says a port is not set in `.env`, add a line for it, for example `NAMENODE_UI_PORT=9871`.
- **After restarting your computer or Docker, things fail with "unknown host" or a service is missing:** containers do not restart by themselves. Run `sh scripts/platform.sh up`.
- **A container disappears, or things become very slow:** you are probably out of memory. Switch off modules you do not need (step 4), or give Docker more memory.
- **Cassandra and Neo4j are slow to start.** Wait for `sh scripts/platform.sh up` to finish before you load data.
- **You changed a password in `.env` after the first start,** and a database now refuses you: the database kept its original password. Run `sh scripts/platform.sh reset`, then start again.
- **Windows:** always use the Ubuntu (WSL) terminal, and keep the project inside the WSL file system.
