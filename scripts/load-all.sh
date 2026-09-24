#!/usr/bin/env bash
# Loads the shared dataset into every currently-running engine, in one command. Skips any
# module that isn't running (based on COMPOSE_PROFILES), rather than failing on it.
set -u
cd "$(dirname "$0")/.."

running() { docker compose ps --status running --services 2>/dev/null | grep -qx "$1"; }

run() {  # run "label" "service-that-must-be-running" command...
  local label="$1" svc="$2"; shift 2
  if running "$svc"; then
    echo "== $label =="
    "$@"
  else
    echo "== $label: skipped ($svc is not running) =="
  fi
}

run "Hive"        hiveserver2 sh scripts/platform.sh load-sample
run "PostgreSQL + MySQL" postgres    sh scripts/platform.sh load-sql
run "MongoDB"     mongo       sh scripts/platform.sh load-mongo
run "Cassandra"   cassandra   sh scripts/platform.sh load-cassandra
run "Neo4j"       neo4j       sh scripts/platform.sh load-neo4j
run "ClickHouse"  clickhouse  sh scripts/platform.sh load-clickhouse
run "DuckDB"      tools       sh scripts/platform.sh demo-duckdb
echo "== load-all: done =="
