#!/usr/bin/env sh
# Memory used by this project's containers (whatever the Compose project is called).
#   sh scripts/mem.sh                 total right now
#   sh scripts/mem.sh peak [seconds]  highest total seen while you run a workload (default 120)
cd "$(dirname "$0")/.." || exit 1
snapshot() {
  ids="$(docker compose ps -q 2>/dev/null)"
  [ -n "$ids" ] || { echo "0 0"; return; }
  # shellcheck disable=SC2086
  docker stats --no-stream --format '{{.Name}} {{.MemUsage}}' $ids | awk '
    { n = $2; u = n; sub(/[0-9.]+/, "", u); v = n + 0
      if (u == "GiB") v *= 1024; else if (u == "KiB") v /= 1024; else if (u == "B") v /= 1048576
      t += v; c++ }
    END { printf "%.0f %d\n", t, c }'
}
show() { awk -v m="$1" -v c="$2" -v label="$3" 'BEGIN { printf "%s: %d MiB (%.2f GiB) across %d containers\n", label, m, m / 1024, c }'; }
case "${1:-now}" in
  now)
    set -- $(snapshot); show "${1:-0}" "${2:-0}" "now" ;;
  peak)
    secs="${2:-120}"; max=0; count=0
    end=$(( $(date +%s) + secs ))
    echo "Sampling for ${secs}s. Run your heaviest work in another terminal now..."
    while [ "$(date +%s)" -lt "$end" ]; do
      set -- $(snapshot); m="${1:-0}"; c="${2:-0}"
      if [ "$m" -gt "$max" ]; then max="$m"; count="$c"; fi
      sleep 3
    done
    show "$max" "$count" "peak over ${secs}s" ;;
  *) echo "usage: sh scripts/mem.sh [now | peak [seconds]]" ;;
esac
