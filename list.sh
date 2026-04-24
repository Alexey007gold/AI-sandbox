#!/bin/bash
docker ps --format "{{.Names}}" | grep "^sbx-" | while read c; do
  echo "$c"
  docker exec "$c" sh -c "awk 'FNR==2' /tmp/session.* 2>/dev/null" | while read dir; do
    echo "  $dir"
  done
done