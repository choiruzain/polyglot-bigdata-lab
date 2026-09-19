#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")/.."
cmd="${1:-help}"
case "$cmd" in
  init)   sh scripts/init-env.sh ;;
  up)     [ -f .env ] || sh scripts/init-env.sh
          sh scripts/make_trino_catalogs.sh
          docker compose up -d --build --wait ;;
  stop)   docker compose stop ;;
  status) docker compose ps --format 'table {{.Service}}\t{{.Status}}\t{{.Ports}}'
          docker stats --no-stream --format 'table {{.Name}}\t{{.MemUsage}}' | grep -E 'NAME|dataplatform' ;;
  shell)  docker compose exec tools bash ;;
  data)   docker compose exec -T tools python3 scripts/make_sample_data.py data/shop ;;
  load-sample)
          sh scripts/platform.sh data
          docker compose exec -T tools spark-submit scripts/load_sample_hive.py 2>&1 | grep -E '^LOADED|Exception|Caused by' ;;
  load-sql)
          docker compose exec -T tools python3 scripts/load_sample_sql.py ;;
  load-mongo)
          docker compose exec -T tools python3 scripts/load_sample_mongo.py ;;
  load-cassandra)
          docker compose exec -T cassandra bash /scripts/init.sh
          docker compose exec -T tools python3 scripts/load_sample_cassandra.py ;;
  load-neo4j)
          docker compose exec -T tools python3 scripts/load_sample_neo4j.py ;;
  load-clickhouse)
          docker compose exec -T tools python3 scripts/load_sample_clickhouse.py ;;
  demo-duckdb)
          docker compose exec -T tools python3 notebooks/t7_duckdb.py ;;
  reset)  printf 'This DELETES all data in this project (HDFS, Hive metadata). Type yes to continue: '
          read -r ans
          [ "$ans" = "yes" ] || { echo "Cancelled."; exit 1; }
          docker compose down -v ;;
  *)      echo "Usage: sh scripts/platform.sh {init|up|stop|status|shell|data|load-sample|load-sql|load-mongo|load-cassandra|load-neo4j|load-clickhouse|demo-duckdb|reset}" ;;
esac
