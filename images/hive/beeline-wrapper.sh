#!/bin/bash
# Beeline's terminal library (JLine 3.25 on Java 21) cannot create a terminal under "docker exec",
# even with a TTY, and needs the preview flag on top. "script" gives beeline a terminal of its own,
# so beeline also works from scripts and tests.
export HADOOP_CLIENT_OPTS="--enable-preview --enable-native-access=ALL-UNNAMED ${HADOOP_CLIENT_OPTS:-}"
cmd="${BEELINE_REAL:-/opt/hive/bin/beeline}"
for a in "$@"; do cmd="$cmd $(printf '%q' "$a")"; done
exec script -qec "$cmd" /dev/null
