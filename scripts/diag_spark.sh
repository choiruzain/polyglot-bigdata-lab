#!/bin/sh
# Usage: sh scripts/diag_spark.sh <script.py> [seconds-to-wait]
# Runs a Spark script; if it is still running after the wait, shows what it is doing, then stops it.
script="$1"; wait="${2:-75}"
export PYTHONUNBUFFERED=1
spark-submit "$script" > /tmp/diag.out 2>&1 &
pid=$!
sleep "$wait"
echo "--- output so far (logging noise removed)"
grep -v '^SLF4J' /tmp/diag.out | tail -n 15
echo "--- memory (MB)"; free -m
if kill -0 "$pid" 2>/dev/null; then
  echo "--- still running after ${wait}s (pid $pid): busy threads"
  jstack "$pid" > /tmp/diag.jstack 2>&1
  awk 'BEGIN{RS="";ORS="\n\n"} /py4j|org\.apache\.spark\.sql|hive\.metastore|neo4j|netty/ {n=split($0,l,"\n"); for(i=1;i<=n&&i<=9;i++) print l[i]}' /tmp/diag.jstack | head -n 80
  kill "$pid" 2>/dev/null; pkill -f SparkSubmit 2>/dev/null || true
else
  echo "--- finished on its own"
fi
