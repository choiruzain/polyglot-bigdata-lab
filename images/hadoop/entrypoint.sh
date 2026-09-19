#!/usr/bin/env sh
set -eu
case "${1:-}" in
  namenode)
    if [ ! -f /opt/hadoop/data/namenode/current/VERSION ]; then
      echo "First start: formatting the NameNode"
      hdfs namenode -format -nonInteractive
    fi
    exec hdfs namenode ;;
  datanode)
    exec hdfs datanode ;;
  *)
    exec "$@" ;;
esac
