#!/usr/bin/env bash
# Starts the platform ("docker compose up"). If Docker says a port on this computer is already
# taken, that port is moved to the next free number in .env and the start is tried again.
set -u
cd "$(dirname "$0")/.." || exit 1

port_in_use() { (exec 3<>"/dev/tcp/127.0.0.1/$1") >/dev/null 2>&1; }

attempt=1
max=10
while :; do
  log="$(mktemp)"; rcfile="$(mktemp)"
  { docker compose up -d --build --wait; echo $? > "$rcfile"; } 2>&1 | tee "$log"
  rc="$(cat "$rcfile")"
  if [ "$rc" -eq 0 ]; then rm -f "$log" "$rcfile"; exit 0; fi

  # Was it a busy port? Docker words this in two ways.
  port="$(grep -oE '(exposing port TCP|Bind for) [0-9.]+:[0-9]+' "$log" | tail -n 1 | sed -E 's/.*:([0-9]+)$/\1/')"
  rm -f "$log" "$rcfile"
  if [ -z "$port" ]; then exit "$rc"; fi

  var="$(grep -E "^[A-Z0-9_]*PORT=${port}\$" .env 2>/dev/null | head -n 1 | cut -d= -f1)"
  if [ -z "$var" ]; then
    echo
    echo "Port $port on this computer is already in use, and it is not set in .env."
    echo "Add a line such as  SOMETHING_PORT=$((port + 1))  to .env (see .env.example for the names), or stop the program that uses port $port."
    exit "$rc"
  fi
  if [ "$attempt" -ge "$max" ]; then
    echo; echo "Still could not find free ports after $max tries. Edit the *_PORT numbers in .env by hand."; exit "$rc"
  fi

  p=$((port + 1))
  while port_in_use "$p" || grep -qE "^[A-Z0-9_]*PORT=${p}\$" .env; do p=$((p + 1)); done
  sed "s/^${var}=.*/${var}=${p}/" .env > .env.new && mv .env.new .env && chmod 600 .env
  echo
  echo ">>> Port $port is already in use on this computer. Moved $var to $p in .env and trying again (attempt $((attempt + 1)) of $max)."
  echo
  docker compose down >/dev/null 2>&1
  attempt=$((attempt + 1))
done
