#!/bin/bash
set -e
PW=""
for i in $(seq 1 30); do
  if cqlsh -u cassandra -p "$CASSANDRA_ROOT_PASSWORD" -e "SELECT release_version FROM system.local" >/dev/null 2>&1; then
    PW="$CASSANDRA_ROOT_PASSWORD"; break
  elif cqlsh -u cassandra -p cassandra -e "SELECT release_version FROM system.local" >/dev/null 2>&1; then
    cqlsh -u cassandra -p cassandra -e "ALTER ROLE cassandra WITH PASSWORD = '$CASSANDRA_ROOT_PASSWORD'"
    PW="$CASSANDRA_ROOT_PASSWORD"; break
  fi
  sleep 5
done
[ -n "$PW" ] || { echo "Cassandra is not ready or the superuser password is unknown"; exit 1; }
cqlsh -u cassandra -p "$PW" -e "CREATE KEYSPACE IF NOT EXISTS shop WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1}; CREATE ROLE IF NOT EXISTS student WITH PASSWORD = '$CASSANDRA_STUDENT_PASSWORD' AND LOGIN = true; GRANT ALL PERMISSIONS ON KEYSPACE shop TO student;"
echo CASSANDRA_INIT_OK
