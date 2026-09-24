#!/usr/bin/env bash
# Runs every cross-engine example and prints only the TOTAL_ lines, so every engine's
# independently-computed revenue total can be eyeballed together in one place. Skips any
# check whose engines aren't running.
set -u
cd "$(dirname "$0")/.."

running() { docker compose ps --status running --services 2>/dev/null | grep -qx "$1"; }

check() {  # check "label" "service-that-must-be-running" command...
  local label="$1" svc="$2"; shift 2
  if running "$svc"; then
    echo "== $label =="
    "$@"
  else
    echo "== $label: skipped ($svc is not running) =="
  fi
}

check "Hive + PostgreSQL + MySQL" postgres   sh -c "docker compose exec -T tools spark-submit notebooks/t4_jdbc.py 2>&1 | grep TOTAL_"
check "MongoDB + Hive"            mongo      sh -c "docker compose exec -T tools spark-submit notebooks/t5_mongo.py 2>&1 | grep TOTAL_"
check "Neo4j"                     neo4j      sh -c "docker compose exec -T tools spark-submit notebooks/t6_neo4j.py 2>&1 | grep TOTAL_"
check "Cassandra"                 cassandra  sh -c "docker compose exec -T tools python3 notebooks/t8_cassandra.py 2>&1 | grep TOTAL_"

# federated.sql joins Postgres + ClickHouse + MySQL + Cassandra, so it genuinely needs all four,
# not just Trino itself -- checking only "trino" would fail by default now that Cassandra is off.
if running trino && running cassandra; then
  echo "== Trino (federated, needs Cassandra too) =="
  docker compose exec -T trino trino --output-format ALIGNED --file /scripts/federated.sql
else
  echo "== Trino (federated, needs Cassandra too): skipped (needs both trino and cassandra running) =="
fi
echo "== verify-all: done =="
