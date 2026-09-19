#!/usr/bin/env sh
# Download one jar from Maven Central and verify its published SHA-1.
# Usage: fetch_jar.sh <path-under-maven2> <destination-folder>
set -eu
path="$1"
dest="$2"
file="$dest/$(basename "$path")"
base="https://repo1.maven.org/maven2/$path"
curl -fsSL -o "$file" "$base"
curl -fsSL -o /tmp/jar.sha1 "$base.sha1"
echo "$(cut -c1-40 /tmp/jar.sha1)  $file" | sha1sum -c -
rm -f /tmp/jar.sha1
