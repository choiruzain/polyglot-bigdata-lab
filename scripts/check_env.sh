#!/usr/bin/env sh
# Maintainer check: does .env.example cover every variable docker-compose.yml needs,
# and is it free of real secrets? A gap only shows up for students, because the
# maintainer's own .env already has every variable.
cd "$(dirname "$0")/.." || exit 1
bad=0

names="$(grep -oE '\$\{[A-Z_][A-Z0-9_]*' docker-compose.yml | sed 's/^\${//' | sort -u)"
for n in $names; do
  grep -q "^$n=" .env.example && continue
  if grep -qF "\${$n:?" docker-compose.yml; then
    echo "MISSING (required): $n is required by docker-compose.yml but is not in .env.example"; bad=1
  else
    echo "note: $n has a default in docker-compose.yml and is not in .env.example (fine)"
  fi
done

# Secrets in the template must be placeholders.
leaks="$(grep -E '^[A-Z0-9_]*(PASSWORD|TOKEN|SECRET)[A-Z0-9_]*=' .env.example | grep -v '=CHANGE_ME$' || true)"
if [ -n "$leaks" ]; then
  echo "POSSIBLE REAL SECRET in .env.example (should be CHANGE_ME):"; echo "$leaks" | sed 's/=.*/=.../; s/^/    /'; bad=1
fi

# The real .env must never be committed.
if git ls-files --error-unmatch .env >/dev/null 2>&1; then echo ".env is tracked by Git: remove it with  git rm --cached .env"; bad=1; fi
grep -qx '.env' .gitignore 2>/dev/null || { echo ".gitignore does not list .env"; bad=1; }

# Every script or config file the platform runs must be tracked by Git. A file that exists only on
# the maintainer's machine works for them and fails for every student (this is how a missing
# scripts/init-env.sh once slipped through).
refs="$(grep -ohE '(^|[^A-Za-z0-9_./-]|\./)(scripts|config|notebooks)/[A-Za-z0-9_./-]+\.(sh|py|sql|cql|cypher|js|xml|conf|properties|ipynb)' scripts/platform.sh docker-compose.yml 2>/dev/null | sed -E 's#^[^a-z]*##' | sort -u)"
for f in $refs; do
  case "$f" in config/trino/catalog/*) continue ;; esac
  if ! git ls-files --error-unmatch "$f" >/dev/null 2>&1; then
    if [ -f "$f" ]; then
      echo "NOT COMMITTED: $f is used by platform.sh or docker-compose.yml but Git does not track it (git add $f)"
    else
      echo "MISSING FILE: $f is used by platform.sh or docker-compose.yml but does not exist"
    fi
    bad=1
  fi
done

# Placeholders that nothing uses are probably stale.
for n in $(grep -E '=CHANGE_ME$' .env.example | cut -d= -f1); do
  grep -qF "\${$n" docker-compose.yml || echo "note: $n=CHANGE_ME is in .env.example but docker-compose.yml never uses it"
done

if [ "$bad" -eq 0 ]; then echo "check_env: OK"; else echo "check_env: PROBLEMS FOUND"; fi
exit "$bad"
