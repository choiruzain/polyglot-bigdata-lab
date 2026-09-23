#!/usr/bin/env bash
# Clears run outputs from every notebook under notebooks/, in place. Safe to run any time —
# only touches notebooks that actually have outputs, and reports which ones it changed.
set -eu
cd "$(dirname "$0")/.."
for nb in notebooks/*.ipynb; do
  [ -f "$nb" ] || continue
  python3 - "$nb" <<'PY'
import json, sys
p = sys.argv[1]
nb = json.load(open(p, encoding="utf-8"))
changed = False
for c in nb["cells"]:
    if c.get("cell_type") == "code":
        if c.get("outputs") or c.get("execution_count") is not None:
            changed = True
        c["outputs"] = []
        c["execution_count"] = None
if changed:
    with open(p, "w", encoding="utf-8") as f:
        json.dump(nb, f, indent=1, ensure_ascii=False)
        f.write("\n")
    print(f"cleared: {p}")
PY
done
