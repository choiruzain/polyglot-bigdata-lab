#!/usr/bin/env sh
set -eu
case "${1:-}" in
  metastore)
    echo "Waiting for HDFS to leave safe mode"
    until HADOOP_USER_NAME=hadoop hdfs dfsadmin -safemode get 2>/dev/null | grep -q OFF; do sleep 2; done
    echo "Creating warehouse directories (dev setup: acting as HDFS superuser)"
    HADOOP_USER_NAME=hadoop hdfs dfs -mkdir -p /user/hive/warehouse /tmp/hive
    HADOOP_USER_NAME=hadoop hdfs dfs -chmod 1777 /tmp /tmp/hive /user/hive/warehouse
    HADOOP_USER_NAME=hadoop hdfs dfs -chown hive:hive /user/hive
    if ! schematool -dbType postgres -info >/dev/null 2>&1; then
      echo "First start: initialising the metastore schema"
      schematool -dbType postgres -initSchema
    fi
    exec hive --service metastore ;;
  hiveserver2)
    # Hive refuses to start if an old PID file names a live process. In a container
    # that process is always PID 1, so a restart would block itself. Start clean.
    export HIVESERVER2_PID_DIR=/tmp/hiveserver2-pid
    rm -rf "$HIVESERVER2_PID_DIR"
    exec hive --service hiveserver2 ;;
  *)
    exec "$@" ;;
esac
