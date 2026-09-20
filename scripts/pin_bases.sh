#!/usr/bin/env bash
# Pins every base image in images/*/Dockerfile to an exact digest, so a rebuild next month gets
# the same Java as today. Run it again later to move to newer base images on purpose.
set -euo pipefail
cd "$(dirname "$0")/.."
command -v docker >/dev/null || { echo "docker is needed."; exit 1; }

refs="$({ grep -hE '^FROM ' images/*/Dockerfile | awk '{print $2}' | grep -v '^scratch$' | sed 's/@sha256:[0-9a-f]*$//' | sort -u; } || true)"
[ -n "$refs" ] || { echo "No FROM lines found in images/*/Dockerfile."; exit 1; }

map="$(mktemp)"
for ref in $refs; do
  digest="$({ docker buildx imagetools inspect "$ref" 2>/dev/null | sed -n 's/^Digest:[[:space:]]*//p' | head -n 1; } || true)"
  if ! printf '%s' "$digest" | grep -qE '^sha256:[0-9a-f]{64}$'; then
    echo "Could not read the digest of $ref (got: '${digest}'). Nothing was changed."; rm -f "$map"; exit 1
  fi
  echo "$ref $digest" >> "$map"
  echo "  $ref -> $digest"
done

for f in images/*/Dockerfile; do
  awk -v mapfile="$map" 'BEGIN { while ((getline line < mapfile) > 0) { split(line, a, " "); d[a[1]] = a[2] } }
    $1 == "FROM" { r = $2; sub(/@sha256:[0-9a-f]+$/, "", r); if (r in d) $2 = r "@" d[r] }
    { print }' "$f" > "$f.new" && mv "$f.new" "$f"
done
rm -f "$map"
echo "--- FROM lines now:"; grep -H '^FROM ' images/*/Dockerfile
echo "Pinned. Rebuild to confirm:  docker compose build"
