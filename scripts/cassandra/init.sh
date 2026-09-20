#!/bin/bash
# Prepares Cassandra: replaces the default superuser password, then creates the "shop" keyspace
# and the "student" role. Safe to run again. Cassandra caches logins for a moment after a change,
# so every step waits and retries, and says which step failed.
ERR="$(mktemp)"
say() { echo "CASSANDRA_INIT: $*"; }
q() {  # q USER PASSWORD CQL : run one statement, retrying for up to about a minute
  local i
  for i in $(seq 1 20); do
    if cqlsh -u "$1" -p "$2" -e "$3" >/dev/null 2>"$ERR"; then return 0; fi
    sleep "${INIT_RETRY_SLEEP:-3}"
  done
  return 1
}
fail() { say "FAILED: $1"; tail -n 2 "$ERR" | sed 's/^/    /'; exit 1; }

say "waiting for the superuser login"
PW=""
for i in $(seq 1 40); do
  if cqlsh -u cassandra -p "$CASSANDRA_ROOT_PASSWORD" -e "SELECT release_version FROM system.local" >/dev/null 2>&1; then
    PW="$CASSANDRA_ROOT_PASSWORD"; break
  elif cqlsh -u cassandra -p cassandra -e "SELECT release_version FROM system.local" >/dev/null 2>&1; then
    say "first start: replacing the default superuser password"
    q cassandra cassandra "ALTER ROLE cassandra WITH PASSWORD = '$CASSANDRA_ROOT_PASSWORD'" || fail "could not change the superuser password"
    PW="$CASSANDRA_ROOT_PASSWORD"; break
  fi
  sleep "${INIT_SLEEP:-5}"
done
[ -n "$PW" ] || fail "Cassandra accepted neither the default nor the configured superuser password"

say "waiting for the new superuser password to take effect"
q cassandra "$PW" "SELECT release_version FROM system.local" || fail "the new superuser password was not accepted"

say "creating the shop keyspace and the student role"
q cassandra "$PW" "CREATE KEYSPACE IF NOT EXISTS shop WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1}" || fail "could not create the keyspace"
q cassandra "$PW" "CREATE ROLE IF NOT EXISTS student WITH PASSWORD = '$CASSANDRA_STUDENT_PASSWORD' AND LOGIN = true" || fail "could not create the student role"
q cassandra "$PW" "GRANT ALL PERMISSIONS ON KEYSPACE shop TO student" || fail "could not grant permissions"

say "waiting for the student login"
q student "$CASSANDRA_STUDENT_PASSWORD" "SELECT release_version FROM system.local" || fail "the student login does not work (was the password in .env changed after the first start? use: sh scripts/platform.sh reset)"
echo CASSANDRA_INIT_OK
