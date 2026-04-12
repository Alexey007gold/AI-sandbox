#!/bin/bash

AUTO1_DIR="/Users/oleksii/Projects/Auto1"
CURRENT_DIR="$(pwd)"

# Determine workspace: Auto1 parent if we're under it, otherwise current dir
if [[ "$CURRENT_DIR" == "$AUTO1_DIR"* ]]; then
  WORKSPACE="$AUTO1_DIR"
else
  WORKSPACE="$CURRENT_DIR"
fi

# Container name derived from workspace path (unique per workspace)
CONTAINER_NAME="sbx-$(echo "$WORKSPACE" | md5 -q | head -c 8)"

# Unique lock file for this session
SESSION_LOCK="/tmp/session.$$"

cleanup() {
  trap - EXIT INT TERM
  docker exec "$CONTAINER_NAME" rm -f "$SESSION_LOCK" 2>/dev/null
  SESSIONS=$(docker exec "$CONTAINER_NAME" sh -c 'ls /tmp/session.* 2>/dev/null | wc -l' | tr -d ' ')
  if [ "${SESSIONS:-0}" -eq 0 ]; then
    docker stop "$CONTAINER_NAME" > /dev/null
  fi
}
trap cleanup EXIT INT TERM

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

# Register this session
docker exec "$CONTAINER_NAME" touch "$SESSION_LOCK"

# Attach a session
docker exec -it -w "$CURRENT_DIR" "$CONTAINER_NAME" bash -c "claude --dangerously-skip-permissions"
