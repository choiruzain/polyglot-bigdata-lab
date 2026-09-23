# Experimental Scala notebooks for Spark 4.1.3

This optional add-on builds Apache Zeppelin 0.13.0-SNAPSHOT from the exact
commit `9de50ac36e15704642c34f9c41835deb2dd95efc` in
[upstream PR 5465](https://github.com/apache/zeppelin/pull/5465).
The PR is not an Apache release. The source archive is SHA-256 checked.
The build uses the Spark 4.1 profile and Scala 2.13.17, matching the platform's
Spark distribution. It includes the Scala and Spark SQL interpreters.
The dynamically loaded Scala 2.13 REPL adapter is packaged explicitly, using
its upstream Spark compilation baseline and Scala 2.13.17 compiler.

## Start

Run these commands from the repository root after starting the main platform
and loading its Hive sample data. The `dataplatform/tools:local` image must
already exist and contain Spark 4.1.3.

```sh
docker compose -f compose.zeppelin.yml build
docker compose -f compose.zeppelin.yml up -d --wait
python3 scripts/check_zeppelin.py --restart
```

Open <http://127.0.0.1:8090>. The verification script creates a saved notebook
under `Polyglot`, prints its address, and executes Scala, an RDD closure,
Hive table counts, the delivered-order revenue check, and a Spark SQL cell.
An unsuccessful cell causes the script to fail.

The add-on joins `dataplatform_default`. If your main Compose project has a
different name, set `PLATFORM_NETWORK=yourproject_default`. To change the web
port, set `ZEPPELIN_PORT=8091` and pass the corresponding `--url` to the check.
Published access is restricted to localhost because this teaching instance
allows anonymous notebook execution.

## Write a notebook

Create a note using the `spark` interpreter. Scala paragraphs start with:

```scala
%spark
spark.sql("SHOW TABLES IN shop").show(false)
```

SQL paragraphs start with:

```sql
%spark.sql
SELECT category, COUNT(*) AS products
FROM shop.products GROUP BY category ORDER BY category
```

Both run through Spark and use the existing Hive metastore and HDFS. They do
not execute through HiveServer2. Spark runs locally in the Zeppelin container
with two worker threads. Each active Spark interpreter consumes additional
memory beyond the Zeppelin web server.

## Stop and restart

```sh
docker compose -f compose.zeppelin.yml stop
docker compose -f compose.zeppelin.yml up -d --wait
```

Notebooks are kept in the `polyglot-zeppelin_zeppelin-notebooks` Docker volume.
`down` keeps this volume; `down -v` deletes the saved notebooks. Interpreter
settings are currently container-local; recreation restores the built-in
settings and environment. The main platform's services are managed separately.

## Build and validation notes

Verified on 2026-09-23 with Docker Desktop on Apple Silicon:

- Spark 4.1.3, Scala 2.13.17, DataFrame count and an RDD closure.
- Existing Hive catalog: 20,000 orders and 59,858 order items.
- Delivered-order revenue: **19,252,162.85**.
- SQL table output rendered in the browser.
- All four notebook cells passed again after restarting the Spark interpreter.

The runtime image includes a guard for the expected Spark and Scala versions.
This is an add-on integration test against the existing platform; the full
32-check platform clean-clone suite has not been rerun for this addition.

The first build downloads Maven dependencies, compiles the server and Spark
interpreter, and builds the browser UI. Maven and npm caches accelerate retries.
The image omits the upstream postinstall step that downloads Playwright E2E
browsers, which are not supported on the base image's Ubuntu 26 ARM64 release.
All UI compilation steps are retained. Upstream Java/Scala tests are skipped during image assembly; the supplied integration
check exercises the running notebook against the actual platform instead.
The interpreter classpath puts Spark's SLF4J 2.0.17 API ahead of Zeppelin's
bundled SLF4J 1.7 API, avoiding a registration-time logging linkage error.
The browser origin allowlist includes only the two local addresses on the
configured port; a wildcard origin is not needed.
No production-readiness or cross-platform support is implied by this experiment.
