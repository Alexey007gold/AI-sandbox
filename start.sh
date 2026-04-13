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
    echo 'container stopped'
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
      --add-host=host.docker.internal:host-gateway \
      --cap-add NET_ADMIN \
      -v "$WORKSPACE":"$WORKSPACE" \
      -v /Users/oleksii/.claude:/root/.claude \
      -v /Users/oleksii/.claude-mem:/root/.claude-mem \
      -v /Users/oleksii/.claude.json:/root/.claude.json \
      -v /Users/oleksii/.m2:/root/.m2 \
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

# Restrict outbound to host gateway: only allow ports 9090 and 9091
docker exec -u root "$CONTAINER_NAME" sh -c '
  HOST_GW=$(ip route show default | awk "/default/ {print \$3}")
  iptables -C OUTPUT -d "$HOST_GW" -p tcp --dport 9090 -j ACCEPT 2>/dev/null || \
    iptables -A OUTPUT -d "$HOST_GW" -p tcp --dport 9090 -j ACCEPT
  iptables -C OUTPUT -d "$HOST_GW" -p tcp --dport 9091 -j ACCEPT 2>/dev/null || \
    iptables -A OUTPUT -d "$HOST_GW" -p tcp --dport 9091 -j ACCEPT
  iptables -C OUTPUT -d "$HOST_GW" -j DROP 2>/dev/null || \
    iptables -A OUTPUT -d "$HOST_GW" -j DROP
'

# Forward host ports so localhost:PORT inside container reaches host
for PORT in 9090 9091; do
  docker exec -d "$CONTAINER_NAME" sh -c \
    "ss -tlnp | grep -q :${PORT} || socat TCP-LISTEN:${PORT},fork,reuseaddr TCP:host.docker.internal:${PORT}" 2>/dev/null || true
done

# Register this session
docker exec "$CONTAINER_NAME" touch "$SESSION_LOCK"

# Attach a session
docker exec -it -e TERM -e COLORTERM -w "$CURRENT_DIR" "$CONTAINER_NAME" bash -c "claude --dangerously-skip-permissions"
