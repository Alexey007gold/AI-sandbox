#!/bin/bash

CONTAINER_NAME="sbx"
WORKSPACE="/Users/oleksii/Projects/Auto1"

# Start container if not running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    docker start "$CONTAINER_NAME"
  else
    docker run -d \
      --name "$CONTAINER_NAME" \
      -v "$WORKSPACE":"$WORKSPACE" \
      -v /Users/oleksii/.claude:/root/.claude \
      -v /Users/oleksii/.claude-mem:/root/.claude-mem \
      -v /Users/oleksii/.claude.json:/root/.claude.json \
      -e ELASTIC_API_KEY \
      -e KIBANA_URL \
      -e KIBANA_QA_API_KEY \
      -e KIBANA_QA_URL \
      -e KIBANA_PROD_API_KEY \
      -e KIBANA_PROD_URL \
      sbx \
      sleep infinity
  fi
fi

# Attach a session
docker exec -it -w "$(pwd)" "$CONTAINER_NAME" bash -c "claude --dangerously-skip-permissions"

# Stop container if no other sessions are active
PROCS=$(docker exec "$CONTAINER_NAME" ps -eo comm= 2>/dev/null | grep -cv -E '^(sleep|ps)$')
if [ "${PROCS:-0}" -eq 0 ]; then
  docker stop "$CONTAINER_NAME" > /dev/null
fi
