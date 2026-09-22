#!/usr/bin/env bash
# Full teardown + rebuild test: removes this project's containers, volumes, and built images
# (both the full-platform images and the standalone notebook-only image), then you re-run
# `sh scripts/platform.sh up` for a true from-scratch build, matching a brand-new user's first run.
#
# This is NOT the same as `sh scripts/platform.sh reset`:
#   - reset:        erases data/volumes only, keeps built images   -> fast (~seconds)
#   - full-rebuild: erases everything, forces a full rebuild       -> slow (~20-40+ min)
#
# Does NOT touch other Docker projects on this machine.
set -euo pipefail
PROJECT="${COMPOSE_PROJECT_NAME:-dataplatform}"

echo "== Stopping and removing containers + volumes for project: $PROJECT"
docker compose -p "$PROJECT" down -v --remove-orphans 2>&1 || echo "(no running compose project found, continuing)"

echo "== Removing leftover volumes matching project name (if any):"
docker volume ls -q --filter "name=${PROJECT}" | xargs -r docker volume rm

echo "== Removing this project's full-platform images (dataplatform/*):"
docker images "dataplatform/*" --format '{{.Repository}}:{{.Tag}}' | xargs -r docker rmi -f

echo "== Removing the standalone notebook-only image (polyglot-bigdata-lab), if built:"
docker images "polyglot-bigdata-lab" --format '{{.Repository}}:{{.Tag}}' | xargs -r docker rmi -f

if [ "${WIPE_BASE_IMAGES:-0}" = "1" ]; then
  echo "== WIPE_BASE_IMAGES=1: also removing pulled base/database images"
  docker images --format '{{.Repository}}:{{.Tag}}' | grep -E '^(postgres|mysql|mongo|cassandra|neo4j|clickhouse/clickhouse-server|trinodb/trino|eclipse-temurin):' | xargs -r docker rmi -f
fi

echo "== Verifying nothing project-specific is left:"
docker ps -a --format '{{.Names}}' | grep -i "$PROJECT" || echo "  no containers"
docker volume ls -q | grep -i "$PROJECT" || echo "  no volumes"
docker images | grep -i -E "dataplatform|polyglot-bigdata-lab" || echo "  no project images"
echo "== Done. Now run: sh scripts/platform.sh up"
