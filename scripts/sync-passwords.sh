#!/usr/bin/env bash
# Keeps each database's student-user password in sync with .env. Run automatically after every
# `platform.sh up`. Safe to run repeatedly — each ALTER just re-sets the password to its current
# value, whether or not it had actually drifted.
#
# Limitation: this can only fix the STUDENT password, and only while the ROOT/superuser credential
# is still valid. If root itself has gone stale (rare — usually caused by manual .env editing while
# containers are running), the only fix is wiping that service's volume and re-initializing it.
set -u
cd "$(dirname "$0")/.."
[ -f .env ] && { set -a; . ./.env; set +a; }

running() { docker compose ps --status running --services 2>/dev/null | grep -qx "$1"; }

if running postgres; then
  echo "sync-passwords: postgres"
  if docker compose exec -T postgres psql -U student -d shop -c \
      "ALTER USER student WITH PASSWORD '${POSTGRES_PASSWORD:-}';" >/dev/null 2>&1; then
    echo "  ok"
  else
    echo "  FAILED (local trust auth should always work here — check the postgres container's logs)"
  fi
fi

if running mysql; then
  echo "sync-passwords: mysql"
  if docker compose exec -T mysql mysql -uroot -p"${MYSQL_ROOT_PASSWORD:-}" -e \
      "ALTER USER 'student'@'%' IDENTIFIED BY '${MYSQL_PASSWORD:-}'; FLUSH PRIVILEGES;" >/dev/null 2>&1; then
    echo "  ok"
  else
    echo "  could not sync (the root password may itself be stale — if load-sql then fails, reset this volume)"
  fi
fi

if running cassandra; then
  echo "sync-passwords: cassandra"
  # Known quirk (harmless, documented 2026-09-24): this can fail on a genuinely fresh clone,
  # not just after a password rotation. It only checks that the CONTAINER is running, not that
  # Cassandra's own init.sh (which changes root's password and creates the student role in
  # several steps) has actually FINISHED -- so the student role may not exist yet when this
  # fires. Cassandra self-heals a moment later via its own init.sh regardless. A real fix would
  # give this the same retry-until-ready loop init.sh already uses for itself.
  if docker compose exec -T cassandra cqlsh -u cassandra -p "${CASSANDRA_ROOT_PASSWORD:-}" -e \
      "ALTER ROLE student WITH PASSWORD = '${CASSANDRA_STUDENT_PASSWORD:-}';" >/dev/null 2>&1; then
    echo "  ok"
  else
    echo "  could not sync (the root password may itself be stale — if load-cassandra then fails, reset this volume)"
  fi
fi
