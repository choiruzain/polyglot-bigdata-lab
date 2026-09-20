#!/usr/bin/env sh
# Creates .env from .env.example, replacing every "CHANGE_ME" with a random dev-only value.
# Safe to run again: it never overwrites a .env that already has real values.
set -eu
cd "$(dirname "$0")/.."
if [ -f .env ] && ! grep -q '=CHANGE_ME$' .env; then
  echo ".env already has real values; leaving it alone"; exit 0
fi
tmp=$(mktemp)
while IFS= read -r line; do
  case "$line" in
    *=CHANGE_ME)
      key=${line%%=*}
      printf '%s=%s\n' "$key" "$(head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n')" ;;
    *) printf '%s\n' "$line" ;;
  esac
done < .env.example > "$tmp"
mv "$tmp" .env
chmod 600 .env
echo "Wrote .env with generated dev-only passwords"
