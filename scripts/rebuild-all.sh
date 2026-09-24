#!/bin/sh
# scripts/rebuild-all.sh
#
# Full clean rebuild of the lab's data layer:
#   1. remove every container and data volume of this Compose project
#      (all profiles: Hive/HDFS, metastore, Postgres, MySQL, Mongo,
#       Cassandra, Neo4j, ClickHouse, Trino, ...),
#   2. start everything again with the passwords currently in .env,
#   3. stop if password sync failed,
#   4. run load-sample, then every other load-* command in platform.sh.
#
# Docker images are kept (no re-download). Zeppelin notebooks are kept
# unless --include-notebooks is given.
#
# Usage:
#   sh scripts/rebuild-all.sh --dry-run            # show what would happen
#   sh scripts/rebuild-all.sh                      # asks before deleting
#   sh scripts/rebuild-all.sh --yes                # no prompt
#   sh scripts/rebuild-all.sh --include-notebooks  # also wipe notebooks

set -eu
cd "$(dirname "$0")/.."

usage() { sed -n '3,21p' "$0" | sed 's/^# \{0,1\}//'; }

yes=0; dry=0; keep_notebooks=1
for arg in "$@"; do
  case "$arg" in
    -y|--yes)            yes=1 ;;
    -n|--dry-run)        dry=1 ;;
    --include-notebooks) keep_notebooks=0 ;;
    -h|--help)           usage; exit 0 ;;
    *) echo "Unknown option: $arg (see --help)" >&2; exit 2 ;;
  esac
done

# --- sanity checks -----------------------------------------------------------
[ -f .env ] || { echo "No .env. Run: sh scripts/platform.sh init" >&2; exit 1; }
if grep -q 'CHANGE_ME' .env; then
  echo ".env still has CHANGE_ME placeholders. Run: sh scripts/platform.sh init" >&2; exit 1
fi
if [ "$(grep -c '^COMPOSE_PROFILES=' .env)" -ne 1 ]; then
  echo ".env must contain exactly one COMPOSE_PROFILES= line." >&2; exit 1
fi

project=$(docker compose config 2>/dev/null | sed -n 's/^name: *//p' | head -n1)
[ -n "$project" ] || { echo "Could not read the Compose project name." >&2; exit 1; }

# --- discover everything labelled with this project (any profile, any folder) -
containers=$(docker ps -aq --filter "label=com.docker.compose.project=$project")
all_volumes=$(docker volume ls -q --filter "label=com.docker.compose.project=$project")

volumes=""; kept=""
for v in $all_volumes; do
  case "$v" in
    *zeppelin-notebook*)
      if [ "$keep_notebooks" -eq 1 ]; then kept="$kept $v"; continue; fi ;;
  esac
  volumes="$volumes $v"
done

# Loaders: every "load-xxx" case in platform.sh, load-sample first.
loaders=$(grep -oE '^[[:space:]]*"?load-[a-z0-9_-]+' scripts/platform.sh \
            | tr -d ' \t"' | sort -u || true)
[ -n "$loaders" ] || loaders="load-sample load-sql load-mongo"

# Other checkouts sharing this project name (the ~/test2 problem).
here=$(pwd -P)
dirs=$(docker ps -a --filter "label=com.docker.compose.project=$project" \
         --format '{{.Label "com.docker.compose.project.working_dir"}}' | sort -u)

echo
echo "Project:          $project"
echo "Active profiles:  $(grep '^COMPOSE_PROFILES=' .env | cut -d= -f2)"
echo "Containers:       $(echo "$containers" | grep -c . || true) will be removed"
echo "Volumes to DELETE:"
for v in $volumes; do echo "  - $v"; done
[ -z "$kept" ] || { echo "Volumes kept:"; for v in $kept; do echo "  - $v"; done; }
echo "Loaders to run:   $(echo $loaders)"
for d in $dirs; do
  [ -z "$d" ] || [ "$d" = "$here" ] && continue
  echo
  echo "WARNING: containers of '$project' were started from another folder:"
  echo "  $d"
  echo "  Its databases are the same ones being deleted here, and its .env"
  echo "  will no longer match them afterwards. Use one checkout only."
done
echo

[ "$dry" -eq 1 ] && { echo "Dry run: nothing changed."; exit 0; }

if [ "$yes" -ne 1 ]; then
  printf 'ALL data above will be permanently deleted.\nType "rebuild" to continue: '
  read -r answer
  [ "$answer" = "rebuild" ] || { echo "Cancelled."; exit 1; }
fi

# --- delete ------------------------------------------------------------------
# shellcheck disable=SC2086
[ -z "$containers" ] || docker rm -f $containers
# shellcheck disable=SC2086
[ -z "$(echo "$volumes" | tr -d ' ')" ] || docker volume rm $volumes

# --- recreate + sync passwords ------------------------------------------------
log=$(mktemp); status=$(mktemp)
trap 'rm -f "$log" "$status"' EXIT

{ sh scripts/platform.sh up 2>&1; echo $? > "$status"; } | tee "$log"

[ "$(cat "$status")" -eq 0 ] || { echo "platform.sh up failed; not loading data." >&2; exit 1; }
if grep -q 'could not sync' "$log"; then
  echo "Password sync still failed after a clean rebuild (see above)." >&2
  echo "That points to .env or the sync script, not old volumes. Not loading data." >&2
  exit 1
fi

# --- load everything -----------------------------------------------------------
failed=""
if echo "$loaders" | grep -qx 'load-sample'; then
  echo; echo "== load-sample"
  sh scripts/platform.sh load-sample || { echo "load-sample failed; stopping." >&2; exit 1; }
fi
for l in $loaders; do
  [ "$l" = "load-sample" ] && continue
  echo; echo "== $l"
  sh scripts/platform.sh "$l" || failed="$failed $l"
done

echo
if [ -n "$failed" ]; then
  echo "Rebuild finished, but these loaders failed:$failed"
  echo "(A loader fails if its profile is not in COMPOSE_PROFILES.)"
  exit 1
fi
echo "Rebuild complete: all services recreated and all sample data loaded."
