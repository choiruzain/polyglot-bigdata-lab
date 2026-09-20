#!/usr/bin/env bash
# Clean-clone test: proves anyone can go from "git clone" to a working platform.
# It clones the COMMITTED repo into a temp folder, runs it as its own Compose project
# ("cleanroom"), loads every engine and checks that each one reproduces the same revenue total.
#
#   bash scripts/clean_clone_test.sh              normal (uses Docker's build cache)
#   NO_CACHE=1 bash scripts/clean_clone_test.sh   rebuild every image from scratch (slow, big downloads)
#   KEEP=1 bash scripts/clean_clone_test.sh       keep the test containers and folder afterwards
set -uo pipefail

TOTAL="19252162.85"
started="$(date +%s)"
src="$(cd "$(dirname "$0")/.." && pwd)"
cd "$src" || exit 1

if [ -n "$(git status --porcelain)" ]; then
  echo "You have uncommitted changes. This test clones what is COMMITTED, so commit them first."; exit 1
fi
if [ -n "$(docker compose ps -q 2>/dev/null)" ]; then
  echo "Your main platform is running and would compete for ports and memory."
  echo "Stop it first (your data is kept):   docker compose stop"; exit 1
fi

work="$(mktemp -d)"
clone="$work/teaching-data-platform"
pass=0; fail=0; LAST=""

cleanup() {
  cd "$src" 2>/dev/null || true
  if [ -n "${KEEP:-}" ]; then
    echo; echo "KEEP is set: the test folder and containers were left in place:"; echo "    cd $clone && docker compose ps"
    return
  fi
  if [ -d "$clone" ]; then ( cd "$clone" && docker compose down -v >/dev/null 2>&1 ); fi
  rm -rf "$work"
}
trap cleanup EXIT

run() { LAST="$("$@" 2>&1)"; }
has() {  # has "description" "regex"  -> checks the output of the last run
  if printf '%s\n' "$LAST" | grep -qE "$2"; then
    printf 'PASS  %s\n' "$1"; pass=$((pass + 1))
  else
    printf 'FAIL  %s\n' "$1"; printf '%s\n' "$LAST" | grep -v -E '^[[:space:]]+at |^[[:space:]]+\.\.\. ' | tail -n 8 | sed 's/^/        /'; fail=$((fail + 1))
  fi
}
progress_run() {  # progress_run LOGFILE command...   (prints a status line while a long step runs)
  local log="$1"; shift
  "$@" > "$log" 2>&1 &
  local pid=$! t0
  t0="$(date +%s)"
  while kill -0 "$pid" 2>/dev/null; do
    sleep "${HEARTBEAT:-30}"
    kill -0 "$pid" 2>/dev/null || break
    printf '        ... %ds elapsed. Latest: %s\n' "$(( $(date +%s) - t0 ))" "$(tail -n 1 "$log" 2>/dev/null | tr -d '\r' | cut -c1-100)"
  done
  wait "$pid"
}
ok()  { printf 'PASS  %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf 'FAIL  %s\n' "$1"; fail=$((fail + 1)); }

echo "Working folder and logs: $work"
hive_count() {  # hive_count "description": select count(*) from shop.orders through HiveServer2
  run docker compose exec -T hiveserver2 beeline -u jdbc:hive2://localhost:10000 -n student --silent=true --outputformat=csv2 -e "select count(*) from shop.orders"
  if printf '%s\n' "$LAST" | grep -qE '(^|[^0-9])20000([^0-9]|$)'; then
    ok "$1"
  else
    bad "$1"
    printf '%s\n' "$LAST" | grep -v -E '^[[:space:]]+at |^[[:space:]]+\.\.\. |SLF4J' | tail -n 8 | sed 's/^/        /'
    echo "        --- errors in the HiveServer2 log:"
    docker compose exec -T hiveserver2 sh -c 'grep -E "Error|Exception|Caused by" /tmp/hive/hive.log | tail -n 6' 2>&1 | cut -c1-200 | sed 's/^/        /'
  fi
}
echo "== 1. Clone what is committed"
git clone -q "$src" "$clone" || { echo "git clone failed"; exit 1; }
cd "$clone" || exit 1

echo "== 2. Setup: copy the template, generate passwords"
cp .env.example .env
run sh scripts/init-env.sh
left="$(grep -c '=CHANGE_ME$' .env || true)"
if [ "$left" = "0" ]; then ok "init-env.sh replaced every CHANGE_ME"; else bad "init-env.sh left $left CHANGE_ME placeholders"; fi
run sh scripts/check_env.sh
has ".env.example covers every variable Compose needs" 'check_env: OK'

setenv() {  # setenv NAME VALUE
  if grep -q "^$1=" .env; then sed "s|^$1=.*|$1=$2|" .env > .env.new && mv .env.new .env; else echo "$1=$2" >> .env; fi
}
setenv COMPOSE_PROJECT_NAME cleanroom
setenv COMPOSE_PROFILES bigdata-lite,sql,mongo,cassandra,neo4j,clickhouse,trino

port_in_use() { (exec 3<>"/dev/tcp/127.0.0.1/$1") >/dev/null 2>&1; }
taken=" "
port_taken() { port_in_use "$1" && return 0; case "$taken" in *" $1 "*) return 0 ;; esac; return 1; }
for line in $(grep -E '^[A-Z0-9_]*PORT=[0-9]+$' .env); do
  k="${line%%=*}"; v="${line#*=}"; p="$v"
  while port_taken "$p"; do p=$((p + 1)); done
  taken="$taken$p "
  if [ "$p" != "$v" ]; then setenv "$k" "$p"; fi
done

if [ -n "${NO_CACHE:-}" ]; then
  echo "== 3. Build every image from scratch (NO_CACHE): this is slow"
  progress_run "$work/build.log" docker compose build --no-cache || { echo "FAIL: image build"; tail -n 25 "$work/build.log"; exit 1; }
fi

echo "== 4. sh scripts/platform.sh up"
progress_run "$work/up.log" sh scripts/platform.sh up || {
  echo "FAIL: platform.sh up did not finish healthy. Last lines:"; tail -n 25 "$work/up.log"
  echo "--- container states:"; docker compose ps -a; echo "(re-run with KEEP=1 to inspect the containers)"; exit 1; }
ok "platform.sh up: every container healthy"

echo "== 5. Load every engine and check the totals"
run sh scripts/platform.sh load-sample
has "sample data generated and loaded into Hive"  'LOADED order_items 59858'
run docker compose exec -T tools jupyter nbconvert --to notebook --execute --output-dir /tmp notebooks/01_hello_spark.ipynb
has "starter notebook runs end to end"        'Writing [0-9]+ bytes'
run docker compose exec -T tools spark-submit notebooks/t3_hive.py
has "Spark reads Hive tables (t3)"            'ORDERS 20000'
run docker compose exec -T tools sh -c 'cd notebooks/scala-hello && sbt -batch package'
has "Scala example compiles with sbt"          '\[success\]'
run docker compose exec -T tools spark-submit --class HelloScala notebooks/scala-hello/target/scala-2.13/hello-scala_2.13-0.1.0.jar
has "Scala example runs on Spark and reads Hive"  'SCALA_ROWS .*Books,18'
run sh scripts/platform.sh load-sql
has "PostgreSQL loaded"      'PG_LOADED order_items 59858'
has "MySQL loaded"           'MY_LOADED order_items 59858'
run sh scripts/platform.sh load-mongo
has "MongoDB loaded"         'MONGO_LOADED items 59858'
run sh scripts/platform.sh load-cassandra
has "Cassandra initialised"  'CASSANDRA_INIT_OK'
has "Cassandra total"        "CASSANDRA_TOTAL $TOTAL"
run sh scripts/platform.sh load-neo4j
has "Neo4j total"            "NEO4J_TOTAL $TOTAL"
run sh scripts/platform.sh load-clickhouse
has "ClickHouse total"       "CLICKHOUSE_TOTAL $TOTAL"
run sh scripts/platform.sh demo-duckdb
has "DuckDB total"           "DUCKDB_TOTAL $TOTAL"

echo "== 6. Cross-engine checks"
run docker compose exec -T tools spark-submit notebooks/t4_jdbc.py
has "Spark joins Hive + PostgreSQL + MySQL"   "TOTAL_FEDERATED $TOTAL"
run docker compose exec -T tools spark-submit notebooks/t5_mongo.py
has "Spark reads MongoDB"                     "TOTAL_MONGO_ONLY $TOTAL"
run docker compose exec -T tools spark-submit notebooks/t6_neo4j.py
has "Spark reads Neo4j (and exits by itself)" "TOTAL_NEO4J_SPARK $TOTAL"
run docker compose exec -T trino trino --output-format CSV --file /scripts/counts.sql
has "Trino sees all five databases"           'clickhouse.order_items.*59858'
run docker compose exec -T trino trino --output-format CSV --file /scripts/federated.sql
has "Trino federated query (first city)"      'Lima.*2470520.84'
has "Trino federated query (last city)"       'Toronto.*2667785.13'
hive_count "HiveServer2 answers SQL"

echo "== 7. Stop everything, start it again (a laptop that slept overnight)"
docker compose stop >/dev/null 2>&1
progress_run "$work/up2.log" sh scripts/platform.sh up && ok "restart: every container healthy again" || { bad "restart: platform.sh up failed"; tail -n 15 "$work/up2.log"; }
hive_count "Hive data survived the restart"
run docker compose exec -T tools sh -c 'PGPASSWORD="$POSTGRES_PASSWORD" psql -h postgres -U student -d shop -Atc "select count(*) from orders"'
has "PostgreSQL data survived the restart"    '^20000$'

echo "== 8. Memory (idle, everything running)"
mem_line="$(sh scripts/mem.sh 2>&1)"; echo "        $mem_line"
mib="$(printf '%s\n' "$mem_line" | sed -n 's/^now: \([0-9]*\) MiB.*/\1/p')"
if [ -n "$mib" ] && [ "$mib" -lt 12288 ]; then ok "total memory is below 12 GB"; else bad "total memory is not below 12 GB ($mem_line)"; fi

if [ -z "${KEEP:-}" ]; then
  echo "== 9. Reset, then confirm nothing is left behind"
  printf 'yes\n' | sh scripts/platform.sh reset >/dev/null 2>&1
  if [ -z "$(docker volume ls -q --filter name=cleanroom_ 2>/dev/null)" ]; then ok "reset removed every volume"; else bad "reset left volumes behind"; fi
fi

elapsed=$(( $(date +%s) - started ))
echo; echo "== RESULT: $pass passed, $fail failed  (${elapsed}s)"
if [ "$fail" -eq 0 ]; then echo "The committed repo works from a clean clone."; else echo "Fix the FAIL lines above, commit, and run this again."; fi
exit "$fail"
