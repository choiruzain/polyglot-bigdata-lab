#!/usr/bin/env sh
# Resolve the MongoDB Spark Connector once at build time and copy only its jars into Spark.
set -eu
version="$1"
cat > /tmp/noop.py <<'PY'
from pyspark.sql import SparkSession
SparkSession.builder.appName("resolve").getOrCreate().stop()
PY
spark-submit --packages "org.mongodb.spark:mongo-spark-connector_2.13:${version}" \
  --conf spark.sql.catalogImplementation=in-memory /tmp/noop.py
ls /home/student/.ivy2.5.2/jars/org.mongodb*.jar
cp /home/student/.ivy2.5.2/jars/org.mongodb*.jar /opt/spark/jars/
rm -rf /home/student/.ivy2.5.2/* /tmp/noop.py /tmp/hsperfdata_student
