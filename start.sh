#!/bin/bash

AUTO1_DIR="/Users/oleksii/Projects/Auto1"
CURRENT_DIR="$(pwd)"
WORKER_SCRIPT="$HOME/.claude/plugins/marketplaces/thedotmack/plugin/scripts/worker-service.cjs"

# Workspace: Auto1 root if we're under it, otherwise current dir
if [[ "$CURRENT_DIR" == "$AUTO1_DIR"* ]]; then
  WORKSPACE="$AUTO1_DIR"
else
  WORKSPACE="$CURRENT_DIR"
fi

CONTAINER_NAME="sbx-$(echo "$WORKSPACE" | md5 -q | head -c 8)"
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

# Start claude-mem worker on host if not already running
if ! nc -z 127.0.0.1 37777 2>/dev/null && [ -f "$WORKER_SCRIPT" ]; then
  CLAUDE_MEM_WORKER_PORT=37777 bun "$WORKER_SCRIPT" &
  disown $!
  for i in $(seq 1 10); do
    nc -z 127.0.0.1 37777 2>/dev/null && break
    sleep 0.5
  done
fi

# Create or start container
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
      -v /Users/oleksii/.m2:/root/.m2 \
      -e TZ="$(readlink /etc/localtime | sed 's|.*/zoneinfo/||')" \
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

# Symlink host paths so plugin installPaths resolve correctly inside container
docker exec -u root "$CONTAINER_NAME" bash -c "
  mkdir -p /Users/oleksii
  ln -sfn /root/.claude /Users/oleksii/.claude
  ln -sfn /root/.claude-mem /Users/oleksii/.claude-mem
  ln -sfn /root/.claude/claude_.json /root/.claude.json
"

# Restrict outbound to host gateway to allowed ports only
docker exec -u root "$CONTAINER_NAME" sh -c '
  HOST_GW=$(ip route show default | awk "/default/ {print \$3}")
  for PORT in 9090 9091 37777; do
    iptables -C OUTPUT -d "$HOST_GW" -p tcp --dport "$PORT" -j ACCEPT 2>/dev/null || \
      iptables -A OUTPUT -d "$HOST_GW" -p tcp --dport "$PORT" -j ACCEPT
  done
  iptables -C OUTPUT -d "$HOST_GW" -j DROP 2>/dev/null || \
    iptables -A OUTPUT -d "$HOST_GW" -j DROP
'

# Forward allowed ports so localhost:PORT inside container reaches host
for PORT in 9090 9091 37777; do
  docker exec -d "$CONTAINER_NAME" sh -c \
    "ss -tlnp | grep -q :${PORT} || socat TCP-LISTEN:${PORT},fork,reuseaddr TCP:host.docker.internal:${PORT}" 2>/dev/null || true
done

# Register session and attach
docker exec "$CONTAINER_NAME" sh -c "echo '$CURRENT_DIR' > '$SESSION_LOCK'"
docker exec -it -e TERM -e COLORTERM -w "$CURRENT_DIR" "$CONTAINER_NAME" bash -c "claude --dangerously-skip-permissions"
