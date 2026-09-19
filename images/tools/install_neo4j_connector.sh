#!/usr/bin/env sh
# Resolve the Neo4j Spark Connector once at build time and copy its jars into Spark.
set -eu
coords="$1"
cat > /tmp/noop.py <<'PY'
from pyspark.sql import SparkSession
SparkSession.builder.appName("resolve").getOrCreate().stop()
PY
spark-submit --packages "${coords}" --conf spark.sql.catalogImplementation=in-memory /tmp/noop.py
ls /home/student/.ivy2.5.2/jars/org.neo4j*.jar
cp /home/student/.ivy2.5.2/jars/org.neo4j*.jar /opt/spark/jars/
rm -rf /home/student/.ivy2.5.2/* /tmp/noop.py /tmp/hsperfdata_student
