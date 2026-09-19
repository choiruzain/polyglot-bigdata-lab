#!/usr/bin/env sh
# Writes one Trino catalog file for each module that is switched on in COMPOSE_PROFILES.
# Passwords are not written here: Trino reads them from environment variables (${ENV:NAME}).
set -eu
cd "$(dirname "$0")/.."
profiles="${COMPOSE_PROFILES:-}"
[ -n "$profiles" ] || profiles="$(grep '^COMPOSE_PROFILES=' .env 2>/dev/null | cut -d= -f2- || true)"
dc="$(grep '^CASSANDRA_LOCAL_DC=' .env 2>/dev/null | cut -d= -f2- || true)"
dc="${dc:-datacenter1}"
dir=config/trino/catalog
mkdir -p "$dir"
rm -f "$dir"/*.properties
has() { case ",$profiles," in *",$1,"*) return 0 ;; esac; return 1; }

printf 'connector.name=tpch\n' > "$dir/tpch.properties"
if has sql; then
  cat > "$dir/postgresql.properties" <<'EOF_PG'
connector.name=postgresql
connection-url=jdbc:postgresql://postgres:5432/shop
connection-user=student
connection-password=${ENV:POSTGRES_PASSWORD}
EOF_PG
  cat > "$dir/mysql.properties" <<'EOF_MY'
connector.name=mysql
connection-url=jdbc:mysql://mysql:3306
connection-user=student
connection-password=${ENV:MYSQL_PASSWORD}
EOF_MY
fi
if has mongo; then
  cat > "$dir/mongodb.properties" <<'EOF_MG'
connector.name=mongodb
mongodb.connection-url=mongodb://student:${ENV:MONGO_PASSWORD}@mongo:27017/?authSource=shop
EOF_MG
fi
if has cassandra; then
  cat > "$dir/cassandra.properties" <<EOF_CA
connector.name=cassandra
cassandra.contact-points=cassandra
cassandra.native-protocol-port=9042
cassandra.security=PASSWORD
cassandra.load-policy.dc-aware.local-dc=$dc
cassandra.username=student
cassandra.password=\${ENV:CASSANDRA_PASSWORD}
EOF_CA
fi
if has clickhouse; then
  cat > "$dir/clickhouse.properties" <<'EOF_CH'
connector.name=clickhouse
connection-url=jdbc:clickhouse://clickhouse:8123/
connection-user=student
connection-password=${ENV:CLICKHOUSE_PASSWORD}
EOF_CH
fi
echo "Trino catalogs: $(ls "$dir" | sed 's/\.properties$//' | tr '\n' ' ')"
